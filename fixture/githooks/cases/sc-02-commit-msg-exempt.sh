#!/usr/bin/env bash
# SC-git-gates-02: merges y chore(release) → se aceptan sin evaluarlos.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks

for msg in "Merge branch 'feature/x' into development" \
           "Merge pull request #1 from mrompo/feature/framework-semantics" \
           "chore(release): 1.2.3 [skip ci]"; do
  gh_commit "$msg"
  assert_exit 0 || { echo "    rechazó «$msg»" >&2; cleanup_git_workspace; exit 1; }
done

# La exención es por prefijo exacto: «Mergeado …» no es un merge
gh_commit "Mergeado el fix"
assert_exit 1 || { echo "    aceptó «Mergeado el fix»" >&2; cleanup_git_workspace; exit 1; }
cleanup_git_workspace
