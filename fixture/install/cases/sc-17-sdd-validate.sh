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

# Un openspec del repo (node_modules/.bin, donde lo deja una devDependency) no se ejecuta: podría
# vaciar el cableado después de que setup lo compruebe (P6-1)
git_in_ws add -A -- . ':!.gl-ok' && ws_commit "chore: instala spec-sentinel" || fail_case "no se pudo versionar la instalación: $RH_ERR"
S="$WS/.claude/settings.json"; orig="$(cat "$S")"
mkdir -p "$WS/node_modules/.bin"
printf '#!/bin/sh\nprintf "{}\\n" > "%s"\nexit 0\n' "$S" >"$WS/node_modules/.bin/openspec"
chmod +x "$WS/node_modules/.bin/openspec"
run_setup SENTINEL_OPENSPEC_BIN= PATH="$WS/node_modules/.bin:$PATH"
[ "$(cat "$S")" = "$orig" ] || fail_case "setup ejecutó un openspec del repo, que vació el cableado"
assert_out_contains "dentro del repo" || fail_case "la salida no avisa de que ignora el openspec del repo"
run_setup SENTINEL_OPENSPEC_BIN="$WS/node_modules/.bin/openspec"
[ "$(cat "$S")" = "$orig" ] || fail_case "setup ejecutó el openspec del repo de SENTINEL_OPENSPEC_BIN"
rm -rf "$WS/node_modules"

# Si algo cambia los settings mientras setup se ejecuta (aquí, un openspec de fuera), setup no
# termina con 0 sobre un estado que no ha comprobado
printf '#!/bin/sh\nprintf "{}\\n" > "%s"\necho "Totals: 1 passed"\nexit 0\n' "$S" >"$WS.bin/openspec-mut"
chmod +x "$WS.bin/openspec-mut"
run_setup SENTINEL_OPENSPEC_BIN="$WS.bin/openspec-mut"
assert_exit 3 || fail_case "con los settings cambiados durante setup debería terminar con 3: $RH_ERR"
assert_out_contains "mientras se ejecutaba setup" || fail_case "la salida debería decir que algo cambió los settings durante setup"

rm -rf "$WS.bin"
cleanup_git_workspace
