#!/usr/bin/env bash
# SC-git-gates-12: sin bitácora escribible no hay excepción. El rechazo se mantiene, el mensaje lo
# explica y la llave NO se consume (la persona puede reintentarlo cuando arregle la bitácora).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
mkdir -p "$WS/sentinel"
TOKEN="$WS/sentinel/.override"

# Un directorio en lugar del fichero: no se puede escribir, sea quien sea el usuario
mkdir -p "$WS/sentinel/overrides.log"
printf 'hotfix INC-9\n' >"$TOKEN"
gh_commit "arreglado el bug"
assert_exit 1 || fail_case "sin bitácora escribible el commit no debería entrar"
assert_err_contains "sin registro no hay excepción" || fail_case "no explica por qué se deniega"
[ -s "$TOKEN" ] || fail_case "la llave se consumió sin registrarse"
cleanup_git_workspace
