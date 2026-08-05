#!/usr/bin/env bash
# SC-sentinel-guard-08: override con motivo → permite + registro auditado en overrides.log
# SC-sentinel-guard-09: override vacío/ausente → sigue bloqueado
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

mk_workspace
git -C "$WS" checkout -qB main
mkdir -p "$WS/sentinel"
cp "$REPO_ROOT/sentinel/policy.yaml" "$WS/sentinel/policy.yaml"
PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"hotfix\""}}'

# SC-09a: sin override → bloqueado
RH_CWD="$WS" run_hook "$GUARD_HOOK" "$PAYLOAD" SENTINEL_POLICY="$WS/sentinel/policy.yaml"
assert_exit 2 || { cleanup_workspace; exit 1; }

# SC-09b: override vacío → sigue bloqueado y sin log
RH_CWD="$WS" run_hook "$GUARD_HOOK" "$PAYLOAD" SENTINEL_POLICY="$WS/sentinel/policy.yaml" SENTINEL_OVERRIDE=""
assert_exit 2 || { cleanup_workspace; exit 1; }
[ ! -f "$WS/sentinel/overrides.log" ] || { echo "    override vacío no debe loguear" >&2; cleanup_workspace; exit 1; }

# SC-08: override con motivo → pasa y queda auditado (regla, acción y motivo)
RH_CWD="$WS" run_hook "$GUARD_HOOK" "$PAYLOAD" SENTINEL_POLICY="$WS/sentinel/policy.yaml" SENTINEL_OVERRIDE="hotfix INC-123 aprobado por tech lead"
rc=0
assert_exit 0 || rc=1
if [ $rc -eq 0 ]; then
  log="$WS/sentinel/overrides.log"
  [ -f "$log" ] || { echo "    falta overrides.log" >&2; rc=1; }
  grep -q "protected-branches" "$log" 2>/dev/null || { echo "    log sin id de regla" >&2; rc=1; }
  grep -q "INC-123" "$log" 2>/dev/null || { echo "    log sin motivo" >&2; rc=1; }
fi
cleanup_workspace
exit $rc
