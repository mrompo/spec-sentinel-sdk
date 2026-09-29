#!/usr/bin/env bash
# Harness del runner de git hooks (fixture, fase 2+) — el banco de la Esclusa.
# Reutiliza el workspace y los asserts del harness del Centinela y añade commits y pushes
# reales contra los hooks de sentinel/githooks (o contra un directorio de hooks falso).
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../hooks/harness.sh" || exit 1
GITHOOKS_DIR="$REPO_ROOT/sentinel/githooks"

# Aislamiento: ni el config global/de sistema del usuario (firmas GPG, hooksPath propio,
# plantillas) ni su identidad entran en el banco. Sin esto, el resultado dependería de la máquina.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@local
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@local

# mk_git_workspace → repo desechable (como mk_workspace) en una rama feature, con un remoto
# bare local para probar pushes sin red. Aborta si no consigue crearlo.
mk_git_workspace() {
  mk_workspace
  [ -n "$WS" ] && [ -d "$WS/.git" ] || { echo "    no se pudo crear el workspace" >&2; exit 1; }
  git -C "$WS" checkout -qb feature/fixture
  git init -q --bare "$WS.remote"
  git -C "$WS" remote add origin "$WS.remote"
}

# git_in_ws <args…> → git dentro del workspace
git_in_ws() { git -C "$WS" "$@"; }

# use_hooks [dir] → los hooks del workspace pasan a ser los de <dir> (por defecto, la Esclusa)
use_hooks() { git -C "$WS" config core.hooksPath "${1:-$GITHOOKS_DIR}"; }

# _capture <cmd…> → ejecuta en el workspace y deja RH_EXIT, RH_ERR (stdout+stderr: los hooks
# de git escriben en los dos) y RH_OUT
_capture() {
  local outf; outf="$(mktemp)"
  ( cd "$WS" && "$@" ) >"$outf" 2>&1
  RH_EXIT=$?
  RH_ERR="$(cat "$outf")"; RH_OUT="$RH_ERR"
  rm -f "$outf"
}

# gh_commit <mensaje> → commit de lo que haya en staging (--allow-empty: el caso decide qué stagea)
gh_commit() { _capture git commit -q --allow-empty -m "$1"; }

# gh_push <refspec> [VAR=valor …] → push al remoto bare del workspace
gh_push() { local ref="$1"; shift; _capture env "$@" git push -q origin "$ref"; }

cleanup_git_workspace() { [ -n "$WS" ] && rm -rf "$WS.remote"; cleanup_workspace; }
