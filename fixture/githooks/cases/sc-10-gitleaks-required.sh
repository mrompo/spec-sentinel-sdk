#!/usr/bin/env bash
# SC-git-gates-10: gitleaks es obligatorio. Sin él, el entorno está mal configurado: el commit
# se rechaza con la instrucción de instalación, aunque no haya ningún secreto. No es un skip.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

printf 'limpio\n' >"$WS/a.txt"; git_in_ws add a.txt
_capture env SENTINEL_GITLEAKS_BIN=/nonexistent/gitleaks git commit -q -m "feat: a"
assert_exit 1 || fail_case "sin gitleaks el commit no debería entrar"
assert_err_contains "gitleaks es obligatorio" || fail_case "no explica que gitleaks es obligatorio"
assert_err_contains "brew install gitleaks" || fail_case "no da la instrucción de instalación"
case "$RH_ERR" in *"se omite"*) fail_case "la ausencia de gitleaks no puede ser un skip" ;; esac

# Con gitleaks presente, el mismo commit entra
_capture env "$(gl_ok)" git commit -q -m "feat: a"
assert_exit 0 || fail_case "con gitleaks presente el commit debería entrar"
cleanup_git_workspace
