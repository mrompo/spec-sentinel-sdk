#!/usr/bin/env bash
# SC-sdk-version-06: en el clon de un compañero, con la instalación versionada, setup --activate no
# copia ni sustituye nada, aunque la copia del SDK sea otra versión: comprueba que la instalación
# está completa (versionada, sin enlaces simbólicos, con sus ejecutables también en git) y cableada
# en .claude/settings.json, cada script en su evento y el Centinela con un matcher que cubre las
# acciones que escriben, y activa la Esclusa o, si el clon usa otros git hooks, da las líneas para
# encadenarla (exit 3). Si falta algo, lo dice, sale con 1 y no activa nada. Una instalación
# anterior a sdk-version (sin sentinel/.sdk-version) se activa con aviso. La prueba de humo del
# Centinela usa el cableado del clon, no el de la copia del SDK, y antes de activar comprueba que
# bloquea lo que tiene que bloquear.
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

# La skill que ejecuta el agente conoce --activate, y que --downgrade lo decide la persona (P7)
grep -q -e '--activate' "$REPO_ROOT/ai-specs/skills/setup/SKILL.md" || fail_case "SKILL.md debería explicar --activate"
grep -q -e '--downgrade' "$REPO_ROOT/ai-specs/skills/setup/SKILL.md" || fail_case "SKILL.md debería explicar --downgrade"

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
# Al .gitignore y al .gitattributes del clon les falta una línea de setup: --activate no las
# añade (setup sí)
grep -vxF 'sentinel/.backup/' "$clone/.gitignore" >"$clone/.gitignore.tmp" && mv "$clone/.gitignore.tmp" "$clone/.gitignore"
grep -vxF 'sentinel/** text eol=lf' "$clone/.gitattributes" >"$clone/.gitattributes.tmp" \
  && mv "$clone/.gitattributes.tmp" "$clone/.gitattributes"
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

# El Centinela cableado en otro evento que el suyo: Claude Code no lo llama antes de cada acción
jq '.hooks.Stop = ((.hooks.Stop // []) + [.hooks.PreToolUse[] | select([.hooks[]?.command] | map(contains("sentinel-guard.sh")) | any)])
    | .hooks.PreToolUse |= map(select(([.hooks[]?.command] | map(contains("sentinel-guard.sh")) | any) | not))' \
  "$clone/.claude/settings.json" >"$clone/.claude/settings.tmp" && mv "$clone/.claude/settings.tmp" "$clone/.claude/settings.json"
before="$(clone_files)"
activate
not_activated "con el Centinela cableado en Stop y no en PreToolUse" ".claude/settings.json"
in_clone checkout -q -- .claude/settings.json

# En PreToolUse, pero con un matcher que no cubre las acciones que escriben: Claude Code no lo
# llama antes de Bash, Edit ni Write (A4)
jq '(.hooks.PreToolUse[] | select([.hooks[]?.command] | map(contains("sentinel-guard.sh")) | any) | .matcher) = "Read"' \
  "$clone/.claude/settings.json" >"$clone/.claude/settings.tmp" && mv "$clone/.claude/settings.tmp" "$clone/.claude/settings.json"
before="$(clone_files)"
activate
not_activated "con el Centinela cableado solo para Read" "matcher"
in_clone checkout -q -- .claude/settings.json

# post-edit.sh y session-start.sh, también cada uno en su evento (A5)
jq '.hooks.PostToolUse |= map(select(([.hooks[]?.command] | map(contains("post-edit.sh")) | any) | not))' \
  "$clone/.claude/settings.json" >"$clone/.claude/settings.tmp" && mv "$clone/.claude/settings.tmp" "$clone/.claude/settings.json"
before="$(clone_files)"
activate
not_activated "sin post-edit.sh en PostToolUse" ".claude/settings.json"
in_clone checkout -q -- .claude/settings.json
jq '.hooks.Stop = ((.hooks.Stop // []) + .hooks.SessionStart) | del(.hooks.SessionStart)' \
  "$clone/.claude/settings.json" >"$clone/.claude/settings.tmp" && mv "$clone/.claude/settings.tmp" "$clone/.claude/settings.json"
before="$(clone_files)"
activate
not_activated "con session-start.sh en Stop y no en SessionStart" ".claude/settings.json"
in_clone checkout -q -- .claude/settings.json

# Un cableado que nombra el Centinela pero no lo deja decidir: descarta su veredicto (… || true)
# o ni lo ejecuta (true …). La prueba de humo lo descubre con una acción que tiene que
# bloquearse, antes de activar nada (V2)
for neuter in '.command += " || true"' '.command = "true \"$CLAUDE_PROJECT_DIR/sentinel/hooks/sentinel-guard.sh\""'; do
  jq "(.hooks.PreToolUse[].hooks[] | select(.command | contains(\"sentinel-guard.sh\"))) |= ($neuter)" \
    "$clone/.claude/settings.json" >"$clone/.claude/settings.tmp" && mv "$clone/.claude/settings.tmp" "$clone/.claude/settings.json"
  before="$(clone_files)"
  activate
  not_activated "con un cableado que no deja decidir al Centinela ($neuter)" "tiene que bloquear"
  in_clone checkout -q -- .claude/settings.json
done

# pre-commit y pre-push cargan sentinel/adapters/stack.sh: sin él, la Esclusa no funciona
in_clone rm -q sentinel/adapters/stack.sh; before="$(clone_files)"
activate
not_activated "sin sentinel/adapters/stack.sh" "sentinel/adapters/stack.sh — no está"
in_clone reset -q --hard

# Ejecutable en el clon, pero no en git: otro clon lo recibiría sin permiso y git no lo ejecutaría
in_clone update-index --chmod=-x sentinel/githooks/pre-commit; before="$(clone_files)"
activate
not_activated "con sentinel/githooks/pre-commit sin permiso de ejecución en git" "sentinel/githooks/pre-commit"
in_clone update-index --chmod=+x sentinel/githooks/pre-commit

# Un enlace simbólico ejecuta lo que hay fuera de la instalación versionada: en git (un clon sin
# enlaces simbólicos, como en Windows, lo saca como fichero normal) y en el clon
g="$clone/sentinel/hooks/sentinel-guard.sh"
rm "$g" && ln -s /usr/bin/true "$g" && in_clone add sentinel/hooks/sentinel-guard.sh \
  && rm "$g" && in_clone show HEAD:sentinel/hooks/sentinel-guard.sh >"$g" || fail_case "no se pudo versionar el enlace"
before="$(clone_files)"
activate
not_activated "con sentinel/hooks/sentinel-guard.sh como enlace simbólico en git" "enlace simbólico"
in_clone reset -q --hard
rm "$clone/sentinel/githooks/pre-commit" && ln -s /usr/bin/true "$clone/sentinel/githooks/pre-commit"
before="$(clone_files)"
activate
not_activated "con sentinel/githooks/pre-commit como enlace simbólico" "enlace simbólico"
in_clone reset -q --hard

# La prueba de humo lanza el cableado del clon: uno que no deja pasar nada lo dice, aunque el de la
# copia del SDK funcione
jq '.hooks.PreToolUse[].hooks[] |= (if (.command | contains("sentinel-guard.sh")) then .command += "; exit 7" else . end)' \
  "$clone/.claude/settings.json" >"$clone/.claude/settings.tmp" && mv "$clone/.claude/settings.tmp" "$clone/.claude/settings.json"
activate
assert_exit 3 || fail_case "con un cableado del Centinela que no deja pasar nada, --activate debería terminar con 3: $RH_ERR"
assert_out_contains "no deja pasar una acción inocua" || fail_case "debería decir que el cableado del clon no deja pasar lo inocuo: $RH_ERR"
in_clone checkout -q -- .claude/settings.json
in_clone config --unset core.hooksPath || true

rm "$clone/sentinel/.sdk-version"; before="$(clone_files)"
activate
not_activated "con sentinel/.sdk-version borrado del clon" "sentinel/.sdk-version — no está"
in_clone checkout -q -- sentinel/.sdk-version

# Un repo sin el SDK versionado: ahí sí, instalarlo con setup; no hay nada que recuperar
in_clone rm -rq --cached -- sentinel .claude/settings.json; before="$(clone_files)"
activate
not_activated "sin el SDK versionado" "instálalo con setup"
assert_out_lacks "Recupera lo que falta" || fail_case "sin el SDK versionado no hay nada que recuperar: $RH_ERR"
in_clone reset -q

# Una instalación anterior a sdk-version (sin sentinel/.sdk-version en git), completa y cableada:
# la activa y dice que la actualice quien la mantiene; no manda a reinstalar desde el clon, que
# instalaría su copia del SDK sin comprobar la versión (P3)
in_clone rm -q sentinel/.sdk-version; before="$(clone_files)"
activate
assert_exit 0 || fail_case "con una instalación anterior a sdk-version, --activate debería terminar con 0: $RH_ERR"
[ "$(hooks_path)" = "sentinel/githooks" ] || fail_case "con una instalación anterior a sdk-version, --activate debería activar la Esclusa"
[ "$(clone_files)" = "$before" ] || fail_case "con una instalación anterior a sdk-version, --activate no debería escribir nada"
assert_out_contains "anterior a sdk-version" || fail_case "debería decir que la instalación es anterior a sdk-version: $RH_ERR"
assert_out_lacks "instálalo con setup" || fail_case "no debería mandar a reinstalar desde el clon: $RH_ERR"
in_clone reset -q --hard
in_clone config --unset core.hooksPath || true

# Repuesto todo, activa
activate
assert_exit 0 || fail_case "con la instalación repuesta, --activate debería terminar con 0: $RH_ERR"
[ "$(hooks_path)" = "sentinel/githooks" ] || fail_case "con la instalación repuesta, --activate debería activar la Esclusa"

# Los git hooks commiteados sin permiso de ejecución (quien instaló con core.fileMode=false sin
# resolver el pendiente): el clon los recibe sin él, y lo arregla git add --chmod=+x, no un
# git checkout (P5)
git_in_ws update-index --chmod=-x sentinel/githooks/pre-commit && ws_commit "chore: pre-commit sin permiso" \
  || fail_case "no se pudo commitear el hook sin permiso: $RH_ERR"
fresh_clone; before="$(clone_files)"
activate
not_activated "con sentinel/githooks/pre-commit commiteado sin permiso de ejecución" "git add --chmod=+x sentinel/githooks/pre-commit"
git_in_ws update-index --chmod=+x sentinel/githooks/pre-commit && ws_commit "chore: pre-commit con permiso" \
  || fail_case "no se pudo devolver el permiso al hook: $RH_ERR"

# Con una llave sin usar en el clon (la de la acción que bloquea la prueba de humo), la prueba no
# se lanza: la gastaría y la apuntaría en la bitácora
fresh_clone
printf 'prueba\npara: Write:sentinel/hooks/sentinel-guard.sh\n' >"$clone/sentinel/.override"; before="$(clone_files)"
activate
assert_out_contains "gastaría" || fail_case "con una llave sin usar, debería decir que no prueba el bloqueo: $RH_ERR"
[ "$(clone_files)" = "$before" ] || fail_case "con una llave sin usar, --activate no debería gastarla ni escribir la bitácora"

# Una copia del SDK más nueva que distribuye un git hook más, y un clon con core.fileMode=false
# (como los de Git for Windows) que lo ignora: --activate mide la instalación del clon, no la
# lista de la copia (A3)
printf '#!/bin/sh\nexit 0\n' >"$SDK_SRC/sentinel/githooks/post-merge" && chmod +x "$SDK_SRC/sentinel/githooks/post-merge" \
  && git -C "$SDK_SRC" add sentinel/githooks/post-merge && git -C "$SDK_SRC" commit -qm "feat: post-merge" \
  || fail_case "no se pudo añadir un git hook a la copia del SDK"
fresh_clone; in_clone config core.fileMode false
printf 'sentinel/githooks/post-merge\n' >>"$clone/.git/info/exclude"
activate
assert_exit 0 || fail_case "con core.fileMode=false y una copia del SDK más nueva, --activate debería terminar con 0: $RH_ERR"
assert_out_lacks "post-merge" || fail_case "--activate no debería pedir nada de un fichero que el clon no tiene: $RH_ERR"

rm -rf "$clone"
cleanup_git_workspace
exit 0
