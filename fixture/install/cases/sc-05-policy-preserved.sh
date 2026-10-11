#!/usr/bin/env bash
# SC-sdk-setup-05 (parte del instalador): al reinstalar, la política del consumidor y su
# bitácora se conservan intactas; lo distribuido (hooks) se actualiza, con backup si difería.
# La otra mitad —actualizar policy.default.yaml— llega con el slice 6 (separación de la política).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

run_setup
assert_exit 0 || fail_case "la primera instalación debería terminar con 0"

P="$WS/sentinel/policy.yaml"; L="$WS/sentinel/overrides.log"; H="$WS/sentinel/hooks/session-start.sh"
printf '\n  - id: regla-del-consumidor\n    tool: Bash\n    command_re: make deploy\n    mode: block\n    reason: propia\n' >>"$P"
printf '2026-10-01T00:00:00Z | guard | algo | motivo\n' >>"$L"
printf '# tocado por el consumidor\n' >>"$H"
policy="$(cat "$P")"; log="$(cat "$L")"

run_setup
assert_exit 0 || fail_case "la reinstalación debería terminar con 0"
[ "$(cat "$P")" = "$policy" ] || fail_case "la reinstalación pisó la política del consumidor"
[ "$(cat "$L")" = "$log" ] || fail_case "la reinstalación tocó la bitácora"
cmp -s "$H" "$REPO_ROOT/sentinel/hooks/session-start.sh" || fail_case "el hook distribuido no se actualizó"
find "$WS/sentinel/.backup" -path '*/sentinel/hooks/session-start.sh' -type f 2>/dev/null | grep -q . \
  || fail_case "el hook modificado se sobrescribió sin backup"
cleanup_git_workspace
