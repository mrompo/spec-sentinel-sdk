#!/usr/bin/env bash
# SC-sdk-setup-17: con openspec/ en el repo, la política del consumidor nace con sdd: true (nivel
# Método) y el pre-push exigirá openspec validate --strict. Si esa validación ya falla al instalar,
# setup termina con 3 y dice cómo desactivarla (sdd: false, lo decide una persona); sin el CLI, lo
# avisa. Así el primer push no se rechaza por sorpresa (P5-2).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; rm -rf "$WS.bin"; cleanup_git_workspace; exit 1; }
mkdir -p "$WS/openspec/changes/borrador" "$WS.bin"
printf '#!/bin/sh\necho "✗ change/borrador: falta un delta" >&2\nexit 1\n' >"$WS.bin/openspec-ko"
printf '#!/bin/sh\necho "Totals: 1 passed, 0 failed"\nexit 0\n' >"$WS.bin/openspec-ok"
chmod +x "$WS.bin/openspec-ko" "$WS.bin/openspec-ok"

run_setup SENTINEL_OPENSPEC_BIN="$WS.bin/openspec-ko"
assert_exit 3 || fail_case "con sdd: true y openspec validate en rojo debería terminar con 3: $RH_ERR"
assert_out_contains "openspec validate" || fail_case "el pendiente debería nombrar openspec validate"
assert_out_contains "sdd: false" || fail_case "el pendiente debería decir cómo desactivar el nivel Método"
assert_out_contains "falta un delta" || fail_case "el pendiente debería mostrar el fallo de la validación"

run_setup SENTINEL_OPENSPEC_BIN="$WS.bin/openspec-ok"
assert_exit 0 || fail_case "con sdd: true y openspec validate en verde debería terminar con 0: $RH_ERR"

run_setup SENTINEL_OPENSPEC_BIN=/nonexistent/openspec
assert_exit 0 || fail_case "sin el CLI de OpenSpec debería terminar con 0 (solo aviso): $RH_ERR"
assert_out_contains "OpenSpec" || fail_case "sin el CLI de OpenSpec, la salida debería avisarlo"

rm -rf "$WS.bin"
cleanup_git_workspace
