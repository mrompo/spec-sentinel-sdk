#!/usr/bin/env bash
# SC-sdk-setup-01: tras instalar en un repo limpio, sin pasos manuales, la Esclusa rechaza un
# commit no conforme y el Centinela (cableado desde settings.json) bloquea una acción prohibida.
# Fuera de un repo git, el instalador falla y no deja nada a medias.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

run_setup
assert_exit 0 || fail_case "la instalación en un repo limpio debería terminar con 0"

# El enforcement está en su sitio y los git hooks son ejecutables
for f in sentinel/hooks/sentinel-guard.sh sentinel/githooks/commit-msg sentinel/githooks/pre-commit \
         sentinel/githooks/pre-push sentinel/githooks/lib/breakglass.sh sentinel/adapters/stack.sh \
         sentinel/policy.default.yaml sentinel/policy.yaml sentinel/overrides.log; do
  [ -f "$WS/$f" ] || fail_case "falta $f tras instalar"
done
[ -x "$WS/sentinel/githooks/commit-msg" ] || fail_case "commit-msg no es ejecutable"
[ ! -e "$WS/sentinel/.override" ] || fail_case "la llave no se distribuye"
[ "$(git_in_ws config --get core.hooksPath)" = "sentinel/githooks" ] || fail_case "core.hooksPath no apunta a la Esclusa"
grep -qxF "sentinel/.override" "$WS/.gitignore" || fail_case ".gitignore no excluye la llave"

# La Esclusa rechaza un mensaje no conforme y acepta uno conforme
ws_commit "arreglado el bug"
assert_exit 1 || fail_case "la Esclusa no rechazó un commit no conforme"
assert_err_contains "tipo(ámbito)" || fail_case "el rechazo no explica el formato"
ws_commit "chore: primer commit con la Esclusa"
assert_exit 0 || fail_case "la Esclusa rechazó un commit conforme"

# El Centinela: el comando cableado en settings.json bloquea un force-push
S="$WS/.claude/settings.json"
jq -e . "$S" >/dev/null 2>&1 || fail_case "settings.json no es JSON válido"
for ev in PreToolUse PostToolUse SessionStart; do
  [ "$(jq "[.hooks.$ev[]?.hooks[]?.command | select(contains(\"sentinel/hooks/\"))] | length" "$S")" -eq 1 ] \
    || fail_case "settings.json no cablea el Centinela en $ev"
done
cmd="$(jq -r '.hooks.PreToolUse[].hooks[].command | select(contains("sentinel-guard"))' "$S")"
_capture env CLAUDE_PROJECT_DIR="$WS" bash -c \
  "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push --force origin x\"}}' | $cmd"
assert_exit 2 || fail_case "el Centinela instalado no bloqueó un force-push"

# Fuera de un repo git (de verdad: fuera también del SDK, que lo es): fallo duro, sin escribir nada
nogit="$(mktemp -d "${TMPDIR:-/tmp}/sentinel-nogit.XXXXXX")"
git -C "$nogit" rev-parse --git-dir >/dev/null 2>&1 && { rm -rf "$nogit"; fail_case "el directorio temporal está dentro de un repo git: el caso no probaría nada"; }
_capture env "$(gl_ok)" bash "$SETUP" "$nogit"
[ "$RH_EXIT" -eq 1 ] || { rm -rf "$nogit"; fail_case "fuera de un repo git debería salir con 1 (salió $RH_EXIT)"; }
assert_err_contains "no es un repo git" || { rm -rf "$nogit"; fail_case "el fallo debería decir que no es un repo git"; }
[ -z "$(ls -A "$nogit")" ] || { rm -rf "$nogit"; fail_case "fuera de un repo git no debe escribir nada"; }
rm -rf "$nogit"

# En un subdirectorio del repo: fallo duro (la instalación caería en otro sitio), sin escribir nada
mkdir -p "$WS/sub"
_capture env "$(gl_ok)" bash "$SETUP" "$WS/sub"
[ "$RH_EXIT" -eq 1 ] || fail_case "en un subdirectorio debería salir con 1 (salió $RH_EXIT)"
assert_err_contains "no es la raíz del repo" || fail_case "el fallo debería decir que no es la raíz"
[ -z "$(ls -A "$WS/sub")" ] || fail_case "en un subdirectorio no debe escribir nada"
cleanup_git_workspace

# SC-sdk-setup-18: la carpeta personal como repo (dotfiles) no es un proyecto: su .claude/ es la
# configuración de usuario y el cableado fallaría en todos los demás proyectos (P7-1)
mk_git_workspace
before="$(ws_snapshot)"
run_setup HOME="$WS"
assert_exit 1 || fail_case "con el repo en la carpeta personal debería terminar con 1: $RH_ERR"
assert_out_contains "configuración de usuario" || fail_case "el fallo debería decir que .claude/ sería la configuración de usuario"
[ "$before" = "$(ws_snapshot)" ] || fail_case "con el repo en la carpeta personal no debe escribir nada"
mkdir -p "$WS/dev/proj"
_capture env "$(gl_ok)" HOME="$WS" bash "$SETUP" "$WS/dev/proj"
assert_exit 1 || fail_case "en una carpeta sin git propio dentro de la carpeta personal debería terminar con 1"
assert_out_contains "git init" || fail_case "el fallo debería sugerir git init en la carpeta del proyecto"
cleanup_git_workspace
