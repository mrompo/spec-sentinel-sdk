#!/usr/bin/env bash
# SC-sentinel-guard-01: acción que no matchea ninguna regla → exit 0 (pasa)
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

run_hook "$GUARD_HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"echo hola"}}' \
  SENTINEL_POLICY_DEFAULT="$DEFAULT_POLICY" SENTINEL_POLICY="$CONSUMER_POLICY"
assert_exit 0
