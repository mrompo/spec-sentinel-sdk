#!/usr/bin/env bash
# SC-sdk-version-06: en el clon de un compañero, con la instalación versionada, setup --activate no
# copia ni sustituye nada, aunque la copia del SDK sea otra versión: comprueba que la instalación
# está completa (versionada, con sus ejecutables) y cableada en .claude/settings.json, y activa la
# Esclusa o, si el clon usa otros git hooks, da las líneas para encadenarla (exit 3). Si falta
# algo, lo dice, sale con 1 y no activa nada.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
clone="$WS.clone"
fail_case() { echo "    $1" >&2; rm -rf "$clone"; cleanup_git_workspace; exit 1; }
activate() { _capture env "$(gl_ok)" bash "$SETUP" --activate "$clone"; }
in_clone() { git -C "$clone" "$@"; }
hooks_path() { in_clone config --get core.hooksPath || true; }
# clone_files → la huella de los ficheros del clon (fuera de .git): lo que --activate no cambia
clone_files() {
  ( cd "$clone" && find . -path ./.git -prune -o -type f -print \
      | LC_ALL=C sort | while IFS= read -r f; do printf '%s %s\n' "$(cksum <"$f")" "$f"; done )
}
# fresh_clone → un clon recién hecho del workspace: la instalación versionada, sin la Esclusa activa
fresh_clone() { rm -rf "$clone" && git clone -q "$WS" "$clone" || fail_case "no se pudo clonar el workspace"; }
# not_activated <qué> → salió con 1, dijo <texto> y no activó ni escribió nada
not_activated() {
  assert_exit 1 || fail_case "$1: --activate debería negarse y terminar con 1: $RH_ERR"
  assert_out_contains "$2" || fail_case "$1: la salida debería nombrar «$2»: $RH_ERR"
  [ -z "$(hooks_path)" ] || fail_case "$1: no debería activar la Esclusa (core.hooksPath → $(hooks_path))"
  [ "$(clone_files)" = "$before" ] || fail_case "$1: --activate no debería escribir nada"
}

run_setup
assert_exit 0 || fail_case "la instalación debería terminar con 0: $RH_ERR"
git_in_ws add -A -- . ':!.gl-ok' && ws_commit "chore: instala spec-sentinel" || fail_case "no se pudo versionar la instalación: $RH_ERR"
# La copia del SDK de quien activa es más nueva y tiene cambios sin commitear: --activate no la
# instala ni la compara con la instalada (setup sin --activate se negaría)
printf '\n# más nuevo\n' >>"$SDK_SRC/sentinel/hooks/README.md"
git -C "$SDK_SRC" commit -qam "más nuevo"
printf '\n# sin commitear\n' >>"$SDK_SRC/sentinel/README.md"

# ── El clon de un compañero: activa la Esclusa y no copia nada ───────────────────────────────
fresh_clone
# Un stack reconocible: --activate tampoco deja una propuesta de stack.yaml
printf '{"scripts":{"test":"vitest","lint":"eslint ."}}\n' >"$clone/package.json"
before="$(clone_files)"
activate
assert_exit 0 || fail_case "--activate en un clon con la instalación versionada debería terminar con 0: $RH_ERR"
[ "$(hooks_path)" = "sentinel/githooks" ] || fail_case "--activate debería activar la Esclusa (core.hooksPath → «$(hooks_path)»)"
[ "$(clone_files)" = "$before" ] || fail_case "--activate no debería copiar ni sustituir nada: $(in_clone status --porcelain)"
assert_out_contains "Esclusa activada" || fail_case "la salida debería decir que la Esclusa queda activada: $RH_ERR"
assert_out_lacks "Instalando" || fail_case "--activate no instala: la salida no debería decir que instala"
activate
assert_exit 0 || fail_case "con la Esclusa ya activa, --activate debería terminar con 0: $RH_ERR"
[ "$(clone_files)" = "$before" ] || fail_case "la segunda vez, --activate tampoco debería escribir nada"

# ── Con otros git hooks: da las líneas para encadenarla, como setup ──────────────────────────
fresh_clone
printf '#!/bin/sh\nexit 0\n' >"$clone/.git/hooks/pre-commit" && chmod +x "$clone/.git/hooks/pre-commit"
# Al .gitignore del clon le falta una línea de setup: --activate no la añade (setup sí)
grep -vxF 'sentinel/.backup/' "$clone/.gitignore" >"$clone/.gitignore.tmp" && mv "$clone/.gitignore.tmp" "$clone/.gitignore"
before="$(clone_files)"
activate
assert_exit 3 || fail_case "con otros git hooks, --activate debería terminar con 3: $RH_ERR"
assert_out_contains 'sentinel/githooks/pre-commit "$@"' || fail_case "con otros git hooks, debería dar las líneas de encadenado: $RH_ERR"
[ -z "$(hooks_path)" ] || fail_case "con otros git hooks, no debería activar core.hooksPath (los silenciaría)"
[ "$(clone_files)" = "$before" ] || fail_case "con otros git hooks, --activate no debería escribir nada"

# ── Con la instalación incompleta, lo dice y no activa nada ──────────────────────────────────
fresh_clone
rm "$clone/sentinel/githooks/pre-push"; before="$(clone_files)"
activate
not_activated "sin sentinel/githooks/pre-push" "sentinel/githooks/pre-push — no está"
in_clone checkout -q -- sentinel/githooks/pre-push

in_clone rm -q --cached sentinel/hooks/sentinel-guard.sh; before="$(clone_files)"
activate
not_activated "con el Centinela sin versionar" "sentinel/hooks/sentinel-guard.sh"
in_clone reset -q -- sentinel/hooks/sentinel-guard.sh

chmod -x "$clone/sentinel/githooks/pre-commit"; before="$(clone_files)"
activate
not_activated "con sentinel/githooks/pre-commit sin permiso de ejecución" "sentinel/githooks/pre-commit"
chmod +x "$clone/sentinel/githooks/pre-commit"

jq '.hooks.PreToolUse |= map(select(([.hooks[]?.command] | map(contains("sentinel-guard.sh")) | any) | not))' \
  "$clone/.claude/settings.json" >"$clone/.claude/settings.tmp" && mv "$clone/.claude/settings.tmp" "$clone/.claude/settings.json"
before="$(clone_files)"
activate
not_activated "sin el Centinela cableado" ".claude/settings.json"
in_clone checkout -q -- .claude/settings.json

# Cablea el Centinela, pero con un NaN que jq acepta y Claude Code (JSON.parse) no
sed '1s/^{/{"x": NaN, /' "$clone/.claude/settings.json" >"$clone/.claude/settings.tmp" \
  && mv "$clone/.claude/settings.tmp" "$clone/.claude/settings.json"; before="$(clone_files)"
activate
not_activated "con un .claude/settings.json que Claude Code no carga" "no es JSON válido"
in_clone checkout -q -- .claude/settings.json

in_clone rm -q sentinel/.sdk-version; before="$(clone_files)"
activate
not_activated "sin sentinel/.sdk-version versionado" "sentinel/.sdk-version"
in_clone reset -q --hard

# Repuesto todo, activa
activate
assert_exit 0 || fail_case "con la instalación repuesta, --activate debería terminar con 0: $RH_ERR"
[ "$(hooks_path)" = "sentinel/githooks" ] || fail_case "con la instalación repuesta, --activate debería activar la Esclusa"

rm -rf "$clone"
cleanup_git_workspace
exit 0
