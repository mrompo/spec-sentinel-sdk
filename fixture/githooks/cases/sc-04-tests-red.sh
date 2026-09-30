#!/usr/bin/env bash
# SC-git-gates-04: suite del adaptador en rojo → push rechazado mostrando el fallo. En verde,
# entra. Sin adaptador, se omite con aviso (SC-git-gates-07).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
mkdir -p "$WS/sentinel/adapters"

printf 'tests: echo "3 tests, 1 fallo: test_login"; exit 1\n' >"$WS/sentinel/adapters/stack.yaml"
gh_push HEAD:feature/fixture
assert_exit 1 || fail_case "con la suite en rojo el push no debería entrar"
assert_err_contains "test_login" || fail_case "no muestra la salida de los tests"
[ -z "$(git -C "$WS.remote" branch --list feature/fixture)" ] || fail_case "la rama llegó al remoto"

printf 'tests: true\n' >"$WS/sentinel/adapters/stack.yaml"
gh_push HEAD:feature/fixture
assert_exit 0 || fail_case "con la suite en verde el push debería entrar"

rm -f "$WS/sentinel/adapters/stack.yaml"
git_in_ws commit -q --allow-empty -m "feat: otro"
gh_push HEAD:feature/fixture
assert_exit 0 || fail_case "sin adaptador el push debería entrar"
assert_err_contains "sin adaptador de stack" || fail_case "sin adaptador no avisa"
cleanup_git_workspace
