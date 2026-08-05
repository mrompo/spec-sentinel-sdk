#!/usr/bin/env bash
# SC-sentinel-guard-11: al arrancar sesión el agente recibe rama + cambio activo sin pedirlo
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
SESSION_HOOK="$REPO_ROOT/sentinel/hooks/session-start.sh"

# Workspace con un cambio activo ficticio: rama + nombre del cambio, sin depender
# de qué fase esté abierta en el repo real (el test no debe romperse al archivar).
mk_workspace
mkdir -p "$WS/openspec/changes/cambio-de-prueba"
git -C "$WS" checkout -qB feature/demo
RH_CWD="$WS" run_hook "$SESSION_HOOK" '{}'
rc=0
assert_exit 0 || rc=1
case "$RH_OUT" in *"feature/demo"*) ;; *) echo "    stdout sin la rama: $RH_OUT" >&2; rc=1 ;; esac
case "$RH_OUT" in *"cambio-de-prueba"*) ;; *) echo "    stdout sin el cambio activo: $RH_OUT" >&2; rc=1 ;; esac

# Sin cambios activos: informa "entre fases"
rm -rf "$WS/openspec/changes/cambio-de-prueba"
RH_CWD="$WS" run_hook "$SESSION_HOOK" '{}'
assert_exit 0 || rc=1
case "$RH_OUT" in *"entre fases"*) ;; *) echo "    stdout sin 'entre fases': $RH_OUT" >&2; rc=1 ;; esac
cleanup_workspace
exit $rc
