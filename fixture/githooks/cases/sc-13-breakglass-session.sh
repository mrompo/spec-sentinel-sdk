#!/usr/bin/env bash
# SC-git-gates-13: SENTINEL_OVERRIDE con motivo en el entorno de la sesión salta el rechazo y lo
# registra (sin llave que consumir). Vacío o solo espacios, no vale. La llave de otra acción no
# se gasta con él (revisión de sentinel-paths, V4).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
mkdir -p "$WS/sentinel"
LOG="$WS/sentinel/overrides.log"

for empty in "" "   "; do
  gh_push HEAD:main SENTINEL_OVERRIDE="$empty"
  assert_exit 1 || fail_case "SENTINEL_OVERRIDE='${empty}' no debería valer"
done
[ ! -e "$LOG" ] || fail_case "un override vacío no debería registrarse"

printf 'parche aprobado\npara: Write:sentinel/policy.yaml\n' >"$WS/sentinel/.override"
gh_push HEAD:main SENTINEL_OVERRIDE="release de emergencia INC-11"
assert_exit 0 || fail_case "con SENTINEL_OVERRIDE el push debería entrar"
[ -s "$WS/sentinel/.override" ] || fail_case "con SENTINEL_OVERRIDE, la llave de otra acción debería conservarse"
grep -q "esclusa:pre-push" "$LOG" 2>/dev/null || fail_case "la bitácora no nombra el hook"
grep -q "INC-11" "$LOG" 2>/dev/null || fail_case "la bitácora no tiene el motivo"
cleanup_git_workspace
