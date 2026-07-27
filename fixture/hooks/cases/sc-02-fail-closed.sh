#!/usr/bin/env bash
# SC-sentinel-guard-02: política ausente o ilegible → deniega con instrucción (fail-closed)
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

# a) Política inexistente
run_hook "$GUARD_HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"echo"}}' \
  SENTINEL_POLICY="/nonexistent/policy.yaml"
assert_exit 2 || exit 1
assert_err_contains "política" || exit 1

# b) Política corrupta (sin version:/rules:)
bad="$(mktemp)"
echo "esto no es una política" > "$bad"
run_hook "$GUARD_HOOK" '{"tool_name":"Bash","tool_input":{"command":"echo"}}' SENTINEL_POLICY="$bad"
rm -f "$bad"
assert_exit 2 || exit 1
assert_err_contains "ilegible" || exit 1
exit 0
