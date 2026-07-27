#!/usr/bin/env bash
# SC-sentinel-guard-06: comando destructivo → no se ejecuta sin aprobación humana
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

run_hook "$GUARD_HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"rm -rf build/"}}' \
  SENTINEL_POLICY="$REPO_ROOT/sentinel/policy.yaml"
assert_exit 2 || exit 1
assert_err_contains "confirmación humana" || exit 1

# Con la aprobación humana explícita, pasa
run_hook "$GUARD_HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"rm -rf build/"}}' \
  SENTINEL_POLICY="$REPO_ROOT/sentinel/policy.yaml" SENTINEL_CONFIRM=1
assert_exit 0
