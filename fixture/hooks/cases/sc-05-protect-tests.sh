#!/usr/bin/env bash
# SC-sentinel-guard-05: introducir .skip()/.only() en un test → block
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

run_hook "$GUARD_HOOK" \
  '{"tool_name":"Edit","tool_input":{"file_path":"tests/user.test.js","new_string":"describe.skip(\"user\", () => {})"}}' \
  SENTINEL_POLICY="$REPO_ROOT/sentinel/policy.yaml"
assert_exit 2 || exit 1
assert_err_contains "No se debilita la suite" || exit 1

# Editar un test sin debilitarlo pasa
run_hook "$GUARD_HOOK" \
  '{"tool_name":"Edit","tool_input":{"file_path":"tests/user.test.js","new_string":"expect(user.name).toBe(\"ana\")"}}' \
  SENTINEL_POLICY="$REPO_ROOT/sentinel/policy.yaml"
assert_exit 0
