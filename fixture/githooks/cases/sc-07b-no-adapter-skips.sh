#!/usr/bin/env bash
# SC-git-gates-07: sin adaptador de stack → los hooks omiten lo que depende del stack con
# aviso, sin fallar (un repo recién clonado no debe romperse).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks
[ ! -f "$WS/sentinel/adapters/stack.yaml" ] || { echo "    el workspace no debería traer adaptador" >&2; cleanup_git_workspace; exit 1; }

printf 'limpio\n' >"$WS/a.txt"; git_in_ws add a.txt
_capture env "$(gl_ok)" git commit -q -m "feat: a"
assert_exit 0 || { cleanup_git_workspace; exit 1; }
assert_err_contains "sin adaptador de stack" || { cleanup_git_workspace; exit 1; }
cleanup_git_workspace
