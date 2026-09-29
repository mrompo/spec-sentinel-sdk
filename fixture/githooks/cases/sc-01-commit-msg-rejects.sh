#!/usr/bin/env bash
# SC-git-gates-01: mensaje no conforme → commit rechazado con el formato esperado;
# mensajes conformes (con y sin ámbito, con ruptura «!») → aceptados.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks

gh_commit "arreglado el bug"
assert_exit 1 || { cleanup_git_workspace; exit 1; }
assert_err_contains "tipo(ámbito): descripción" || { cleanup_git_workspace; exit 1; }

for bad in "feat:sin espacio" "feature: tipo inventado" "fix(): ámbito vacío" "docs: " "Fix: mayúscula"; do
  gh_commit "$bad"
  assert_exit 1 || { echo "    aceptó «$bad»" >&2; cleanup_git_workspace; exit 1; }
done

for good in "feat: algo" "fix(guard): algo" "docs(semantics)!: cambio que rompe" "chore(deps-dev): bump" \
            "refactor(sentinel/hooks): mover"; do
  gh_commit "$good"
  assert_exit 0 || { echo "    rechazó «$good»" >&2; cleanup_git_workspace; exit 1; }
done

# Solo cuenta el asunto: las líneas de comentario y el cuerpo no lo sustituyen
gh_commit "$(printf '# comentario de git\nfeat: el asunto real\n\ncuerpo libre sin formato')"
assert_exit 0 || { cleanup_git_workspace; exit 1; }
cleanup_git_workspace
