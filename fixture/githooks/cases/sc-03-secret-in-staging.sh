#!/usr/bin/env bash
# SC-git-gates-03: un secreto en staging → commit rechazado señalando el fichero. La base de
# patrones corre siempre, esté o no gitleaks. Un secreto que NO está en staging no cuenta.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
gl="$(gl_ok)"   # gitleaks falso que no encuentra nada: así se prueba la base de patrones

# Los secretos se componen en tiempo de ejecución para que este fichero no sea uno
aws="AKIA""IOSFODNN7EXAMPLE"
pem="-----BEGIN RSA ""PRIVATE KEY-----"
ghp="ghp_""$(printf 'a%.0s' $(seq 1 36))"

for secret in "$aws" "$pem" "$ghp"; do
  git_in_ws reset -q
  printf 'config = "%s"\n' "$secret" >"$WS/config.txt"
  git_in_ws add config.txt
  _capture env "$gl" git commit -q -m "feat: config"
  assert_exit 1 || fail_case "aceptó un secreto (${secret:0:8}…)"
  assert_err_contains "config.txt" || fail_case "no señala el fichero"
done

# El secreto sin stagear no bloquea: solo se evalúa lo que entra en el commit
git_in_ws reset -q
printf 'limpio\n' >"$WS/ok.txt"; git_in_ws add ok.txt
_capture env "$gl" git commit -q -m "feat: ok"
assert_exit 0 || fail_case "un secreto fuera de staging bloqueó el commit"
cleanup_git_workspace
