#!/usr/bin/env bash
# SC-sentinel-guard-06: comando destructivo → no se ejecuta sin aprobación humana.
# El hook pide la aprobación POR ACCIÓN vía el mecanismo de permisos del harness
# (permissionDecision: ask en stdout), no con una variable de sesión.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

for cmd in "rm -rf build/" "rm -fr build/" "rm  -Rf build/" "git reset --hard HEAD~1" "psql -c 'drop table users'"; do
  run_hook "$GUARD_HOOK" \
    "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}" \
    SENTINEL_POLICY="$REPO_ROOT/sentinel/policy.yaml"
  assert_exit 0 || { echo "    ($cmd)" >&2; exit 1; }
  case "$RH_OUT" in
    *'"permissionDecision":"ask"'*) ;;
    *) echo "    ($cmd) sin permissionDecision ask: $RH_OUT" >&2; exit 1 ;;
  esac
done

# Un comando inocuo no pide nada
run_hook "$GUARD_HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
  SENTINEL_POLICY="$REPO_ROOT/sentinel/policy.yaml"
assert_exit 0 || exit 1
[ -z "$RH_OUT" ] || { echo "    comando inocuo no debe pedir permiso: $RH_OUT" >&2; exit 1; }
exit 0
