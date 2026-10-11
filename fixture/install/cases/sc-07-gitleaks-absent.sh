#!/usr/bin/env bash
# SC-sdk-setup-07: sin gitleaks, la instalación se completa pero avisa YA (no en el primer
# commit) con la instrucción de instalación, y termina con 3 (pasos pendientes).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

run_setup SENTINEL_GITLEAKS_BIN=/nonexistent/gitleaks
assert_exit 3 || fail_case "sin gitleaks debería terminar con 3"
assert_out_contains "gitleaks" || fail_case "la salida no menciona gitleaks"
assert_out_contains "brew install gitleaks" || fail_case "la salida no da la instrucción de instalación"
[ "$(git_in_ws config --get core.hooksPath)" = "sentinel/githooks" ] || fail_case "el resto de la instalación debe completarse"
[ -f "$WS/.claude/settings.json" ] || fail_case "el Centinela debe quedar cableado"
cleanup_git_workspace
