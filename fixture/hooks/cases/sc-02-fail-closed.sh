#!/usr/bin/env bash
# SC-sentinel-guard-02: política distribuida ausente o ilegible, o política del consumidor
# ilegible → deniega con instrucción (fail-closed). Sin política del consumidor → legítimo.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
ECHO='{"tool_name":"Bash","tool_input":{"command":"echo"}}'

# a) Política distribuida inexistente
run_hook "$GUARD_HOOK" "$ECHO" \
  SENTINEL_POLICY_DEFAULT="/nonexistent/policy.default.yaml" SENTINEL_POLICY="$CONSUMER_POLICY"
assert_exit 2 || exit 1
assert_err_contains "política" || exit 1

# b) Política distribuida corrupta (sin version:/rules:)
bad="$(mktemp)"
echo "esto no es una política" > "$bad"
run_hook "$GUARD_HOOK" "$ECHO" SENTINEL_POLICY_DEFAULT="$bad" SENTINEL_POLICY="$CONSUMER_POLICY"
assert_exit 2 || { rm -f "$bad"; exit 1; }
assert_err_contains "ilegible" || { rm -f "$bad"; exit 1; }

# c) Política del consumidor corrupta: tampoco se ignora en silencio
run_hook "$GUARD_HOOK" "$ECHO" SENTINEL_POLICY_DEFAULT="$DEFAULT_POLICY" SENTINEL_POLICY="$bad"
rm -f "$bad"
assert_exit 2 || exit 1
assert_err_contains "ilegible" || exit 1

# d) Sin política del consumidor: pasa (protegen las reglas del SDK)
run_hook "$GUARD_HOOK" "$ECHO" SENTINEL_POLICY_DEFAULT="$DEFAULT_POLICY" SENTINEL_POLICY="$NO_POLICY"
assert_exit 0 || exit 1
exit 0
