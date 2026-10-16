#!/usr/bin/env bash
# SC-sdk-setup-04: con un settings.json previo y sin jq, el fichero queda intacto, se escribe
# sentinel/settings.fragment.json y la salida explica el paso manual (exit 3: pasos pendientes).
# Lo mismo si hay jq pero la fusión no es segura (settings.json que no es JSON válido).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

S="$WS/.claude/settings.json"; F="$WS/sentinel/settings.fragment.json"; mkdir -p "$WS/.claude"
printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo hook-propio"}]}]}}\n' >"$S"
orig="$(cat "$S")"

run_setup SENTINEL_SETUP_JQ=/nonexistent/jq
assert_exit 3 || fail_case "sin jq debería terminar con 3 (pasos pendientes)"
[ "$(cat "$S")" = "$orig" ] || fail_case "sin jq, settings.json debe quedar intacto"
[ -f "$F" ] || fail_case "sin jq debería escribirse sentinel/settings.fragment.json"
grep -q "sentinel-guard" "$F" || fail_case "el fragmento no cablea el Centinela"
assert_out_contains "settings.fragment.json" || fail_case "la salida no explica el paso manual"
[ "$(git_in_ws config --get core.hooksPath)" = "sentinel/githooks" ] || fail_case "el resto de la instalación debe completarse"

# Con jq pero settings.json ilegible: tampoco se toca
printf '{ esto no es json\n' >"$S"; orig="$(cat "$S")"; rm -f "$F"
run_setup
assert_exit 3 || fail_case "con settings.json ilegible debería terminar con 3"
[ "$(cat "$S")" = "$orig" ] || fail_case "un settings.json ilegible no se toca"
[ -f "$F" ] || fail_case "con settings.json ilegible debería escribirse el fragmento"
cleanup_git_workspace

# SC-sdk-setup-02 sin jq: con el cableado ya puesto, reinstalar no escribe el fragmento ni deja
# nada pendiente (A1)
mk_git_workspace
F="$WS/sentinel/settings.fragment.json"
run_setup SENTINEL_SETUP_JQ=/nonexistent/jq
assert_exit 0 || fail_case "sin jq ni settings.json previo, la instalación debería terminar con 0"
before="$(ws_snapshot)"
run_setup SENTINEL_SETUP_JQ=/nonexistent/jq
assert_exit 0 || fail_case "sin jq, reinstalar con el cableado ya puesto debería terminar con 0: $RH_ERR"
[ ! -e "$F" ] || fail_case "sin jq y ya cableado, no debe escribirse el fragmento"
[ "$before" = "$(ws_snapshot)" ] || fail_case "sin jq, la reinstalación cambió el workspace"
cleanup_git_workspace

# Sin jq, la persona hace el paso manual (copia el fragmento): el siguiente setup lo reconoce,
# sale con 0 y retira el fragmento sobrante (P3)
mk_git_workspace
S="$WS/.claude/settings.json"; F="$WS/sentinel/settings.fragment.json"; mkdir -p "$WS/.claude"
printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo hook-propio"}]}]}}\n' >"$S"
run_setup SENTINEL_SETUP_JQ=/nonexistent/jq
assert_exit 3 || fail_case "sin jq y con settings.json previo debería terminar con 3"
jq -s '.[0] as $own | .[1] as $frag
       | $own | .hooks = reduce ($frag.hooks | to_entries[]) as $e (.hooks; .[$e.key] = ((.[$e.key] // []) + $e.value))' \
  "$S" "$F" >"$S.new" && mv "$S.new" "$S"
run_setup SENTINEL_SETUP_JQ=/nonexistent/jq
assert_exit 0 || fail_case "sin jq, con el fragmento ya fusionado a mano, setup debería terminar con 0: $RH_ERR"
[ ! -e "$F" ] || fail_case "con el paso manual hecho, el fragmento sobrante debería retirarse"
cleanup_git_workspace

# Sin jq y con un cableado anterior (matcher sin Read|Grep|Glob): no basta con que estén los
# textos; el pendiente pide sustituir las entradas del SDK, no añadir otras (P2-9, V2-4)
mk_git_workspace
S="$WS/.claude/settings.json"; mkdir -p "$WS/.claude"
jq '.hooks.PreToolUse[0].matcher = "Bash|Edit|Write|MultiEdit|NotebookEdit"' "$REPO_ROOT/.claude/settings.json" >"$S"
run_setup SENTINEL_SETUP_JQ=/nonexistent/jq
assert_exit 3 || fail_case "sin jq y con el matcher antiguo debería terminar con 3"
assert_out_contains "sustituye" || fail_case "con el cableado antiguo, el pendiente debería pedir sustituir las entradas del SDK"
jq '.hooks.PreToolUse[0].matcher' "$REPO_ROOT/.claude/settings.json" >/dev/null
cp "$REPO_ROOT/.claude/settings.json" "$S"
run_setup SENTINEL_SETUP_JQ=/nonexistent/jq
assert_exit 0 || fail_case "sin jq, con las entradas sustituidas, setup debería terminar con 0: $RH_ERR"
cleanup_git_workspace
