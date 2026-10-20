#!/usr/bin/env bash
# SC-sdk-setup-06: el stack se detecta y se PROPONE (stack.proposed.yaml), nunca se aplica solo.
# Con stack.yaml ya declarado, no se propone nada; con un stack desconocido, se avisa sin fallar.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
A="$WS/sentinel/adapters"

# Stack desconocido (demo-app tal cual): aviso, sin propuesta, sin fallo
run_setup
assert_exit 0 || fail_case "un stack desconocido no es un fallo de instalación"
[ ! -e "$A/stack.proposed.yaml" ] || fail_case "con stack desconocido no se propone nada"
assert_out_contains "stack.yaml" || fail_case "la salida no explica cómo declarar el stack"

# Node: se propone, no se aplica
printf '{\n  "scripts": { "test": "vitest", "lint": "eslint ." }\n}\n' >"$WS/package.json"
run_setup
assert_exit 0 || fail_case "con stack Node debería terminar con 0"
grep -q "tests: npm test" "$A/stack.proposed.yaml" 2>/dev/null || fail_case "no se propuso el stack Node"
[ ! -e "$A/stack.yaml" ] || fail_case "la propuesta no se aplica sola"
assert_out_contains "stack.proposed.yaml" || fail_case "la salida no menciona la propuesta"

# Con stack.yaml declarado: no se propone nada (y la propuesta antigua no se toca)
rm -f "$A/stack.proposed.yaml"; printf 'tests: make test\n' >"$A/stack.yaml"
run_setup
assert_exit 0 || fail_case "con stack.yaml declarado debería terminar con 0"
[ ! -e "$A/stack.proposed.yaml" ] || fail_case "con stack.yaml declarado no se propone nada"
[ "$(cat "$A/stack.yaml")" = "tests: make test" ] || fail_case "se pisó el stack.yaml del consumidor"
cleanup_git_workspace
