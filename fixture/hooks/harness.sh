#!/usr/bin/env bash
# Harness del runner de hooks (fixture, fase 1+).
# Simula tool calls contra un hook: JSON por stdin → captura exit code y stderr.
# Workspace: copia de fixture/demo-app a fixture/.tmp/ + git init (repo desechable por test).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD_HOOK="$REPO_ROOT/sentinel/hooks/sentinel-guard.sh"
WS=""

mk_workspace() {
  WS="$REPO_ROOT/fixture/.tmp/ws-$$-$RANDOM"
  mkdir -p "$WS"
  cp -R "$REPO_ROOT/fixture/demo-app/." "$WS/"
  git -C "$WS" init -q
  git -C "$WS" -c user.email=fixture@local -c user.name=fixture add -A
  git -C "$WS" -c user.email=fixture@local -c user.name=fixture commit -qm "init" --allow-empty
}

cleanup_workspace() { [ -n "$WS" ] && rm -rf "$WS"; WS=""; }

# run_hook <hook.sh> <json> [VAR=valor ...] → deja RH_EXIT y RH_ERR
run_hook() {
  local hook="$1" json="$2"; shift 2
  local errf; errf="$(mktemp)"
  printf '%s' "$json" | env "$@" bash "$hook" 2>"$errf" >/dev/null
  RH_EXIT=$?
  RH_ERR="$(cat "$errf")"
  rm -f "$errf"
}

assert_exit() {
  [ "$RH_EXIT" -eq "$1" ] && return 0
  echo "    esperado exit $1, obtenido $RH_EXIT (stderr: $RH_ERR)" >&2
  return 1
}

assert_err_contains() {
  case "$RH_ERR" in *"$1"*) return 0 ;; esac
  echo "    stderr no contiene «$1». stderr: $RH_ERR" >&2
  return 1
}
