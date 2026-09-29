#!/usr/bin/env bash
# SC-git-gates-05: push directo a una rama protegida → rechazado. Aquí el commit ya existe:
# no hay ventana de TOCTOU. La lista sale de la regla protected-branches de la política
# (la misma fuente que el Centinela); sin política, se usa la lista por defecto.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

# Sin política en el workspace: lista por defecto
for b in main master development preproduction production; do
  gh_push "HEAD:$b"
  assert_exit 1 || fail_case "sin política, aceptó un push a $b"
  assert_err_contains "rama protegida" || fail_case "no explica el rechazo ($b)"
done
gh_push HEAD:refs/heads/production
assert_exit 1 || fail_case "aceptó production con refspec completo"
gh_push HEAD:feature/algo
assert_exit 0 || fail_case "rechazó una rama feature"
gh_push HEAD:mainline
assert_exit 0 || fail_case "«mainline» no es «main»"

# Con política: manda su branch_re (aquí solo «trunk» está protegida)
mkdir -p "$WS/sentinel"
cat >"$WS/sentinel/policy.yaml" <<'EOF'
version: 1
sdd: false
rules:
  - id: otra
    branch_re: ^(main)$
    mode: warn
  - id: protected-branches
    tool: Bash
    branch_re: ^(trunk)$
    mode: block
    reason: x
EOF
gh_push HEAD:trunk
assert_exit 1 || fail_case "con política, aceptó trunk"
gh_push HEAD:main
assert_exit 0 || fail_case "con política, «main» no está en protected-branches (el branch_re de otra regla no cuenta)"
cleanup_git_workspace
