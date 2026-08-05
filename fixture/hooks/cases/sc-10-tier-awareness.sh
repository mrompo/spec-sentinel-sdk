#!/usr/bin/env bash
# SC-sentinel-guard-10: spec-guard (requires_sdd) solo aplica con sdd: true
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

mk_workspace   # sin openspec/ → "no hay cambio activo"
PAYLOAD='{"tool_name":"Edit","tool_input":{"file_path":"src/app.js","new_string":"x"}}'

# Tier 0 (sdd: false): la regla no aplica → silencio
tier0="$WS/policy-tier0.yaml"
sed 's/^sdd:.*/sdd: false/' "$REPO_ROOT/sentinel/policy.yaml" > "$tier0"
RH_CWD="$WS" run_hook "$GUARD_HOOK" "$PAYLOAD" SENTINEL_POLICY="$tier0"
assert_exit 0 || { cleanup_workspace; exit 1; }
[ -z "$RH_ERR" ] || { echo "    en Tier 0 no debe avisar: $RH_ERR" >&2; cleanup_workspace; exit 1; }

# Tier 1 (sdd: true) sin cambio activo: warn
tier1="$WS/policy-tier1.yaml"
sed 's/^sdd:.*/sdd: true/' "$REPO_ROOT/sentinel/policy.yaml" > "$tier1"
RH_CWD="$WS" run_hook "$GUARD_HOOK" "$PAYLOAD" SENTINEL_POLICY="$tier1"
rc=0
assert_exit 0 || rc=1
assert_err_contains "warn:spec-guard" || rc=1
cleanup_workspace
exit $rc
