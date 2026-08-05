#!/usr/bin/env bash
# SC-sentinel-guard-07: regla warn → pasa (exit 0) dejando aviso visible
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

run_hook "$GUARD_HOOK" \
  '{"tool_name":"Edit","tool_input":{"file_path":"jest.config.js","new_string":"coverageThreshold: 10"}}' \
  SENTINEL_POLICY="$REPO_ROOT/sentinel/policy.yaml"
assert_exit 0 || exit 1
assert_err_contains "warn:coverage-thresholds" || exit 1
exit 0
