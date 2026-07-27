#!/usr/bin/env bash
# SC-sentinel-guard-11: al arrancar sesión el agente recibe rama + cambio activo sin pedirlo
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
SESSION_HOOK="$REPO_ROOT/sentinel/hooks/session-start.sh"

# En el repo del SDK: rama actual + cambio activo (sentinel-guard)
run_hook "$SESSION_HOOK" '{}'
assert_exit 0 || exit 1
branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
case "$RH_OUT" in
  *"$branch"*) ;;
  *) echo "    stdout sin la rama actual ($branch): $RH_OUT" >&2; exit 1 ;;
esac
case "$RH_OUT" in
  *"sentinel-guard"*) ;;
  *) echo "    stdout sin el cambio activo: $RH_OUT" >&2; exit 1 ;;
esac

# En un workspace sin openspec/: informa "entre fases"
mk_workspace
RH_CWD="$WS" run_hook "$SESSION_HOOK" '{}'
cleanup_workspace
assert_exit 0 || exit 1
case "$RH_OUT" in
  *"entre fases"*) exit 0 ;;
  *) echo "    stdout sin 'entre fases': $RH_OUT" >&2; exit 1 ;;
esac
