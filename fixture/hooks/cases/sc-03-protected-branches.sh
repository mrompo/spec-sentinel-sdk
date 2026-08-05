#!/usr/bin/env bash
# SC-sentinel-guard-03: git commit en rama protegida → block; en rama feature → pasa
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

mk_workspace
git -C "$WS" checkout -qB main

RH_CWD="$WS" run_hook "$GUARD_HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"x\""}}' \
  SENTINEL_POLICY="$REPO_ROOT/sentinel/policy.yaml"
assert_exit 2 || { cleanup_workspace; exit 1; }
assert_err_contains "Rama protegida" || { cleanup_workspace; exit 1; }

git -C "$WS" checkout -qB feature/algo
RH_CWD="$WS" run_hook "$GUARD_HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"x\""}}' \
  SENTINEL_POLICY="$REPO_ROOT/sentinel/policy.yaml"
cleanup_workspace
assert_exit 0
