#!/usr/bin/env bash
# SC-git-gates-07 (base): el adaptador de stack se lee de un único fichero; sin fichero, no hay
# comandos (y quien lo consuma omite con aviso, sin fallar). La autodetección propone un
# stack.yaml para Node y Laravel, pero nunca se aplica sola: los hooks solo leen lo declarado.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1
source "$REPO_ROOT/sentinel/adapters/stack.sh" || { echo "    falta sentinel/adapters/stack.sh" >&2; exit 1; }

mk_git_workspace
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

# Sin adaptador: no disponible y ninguna clave devuelve comando
( cd "$WS" && stack_available ) && fail_case "stack_available sin fichero debería fallar"
[ -z "$(cd "$WS" && stack_get tests)" ] || fail_case "stack_get sin fichero debería estar vacío"

# Con adaptador: lee claves, ignora comentarios, quita comillas y devuelve vacío si falta una
mkdir -p "$WS/sentinel/adapters"
cat >"$WS/sentinel/adapters/stack.yaml" <<'EOF'
# comentario
tests: npm test
lint: "npx eslint"
format-check: 'npx prettier --check'
EOF
( cd "$WS" && stack_available ) || fail_case "stack_available con fichero debería pasar"
[ "$(cd "$WS" && stack_get tests)" = "npm test" ] || fail_case "tests mal leído"
[ "$(cd "$WS" && stack_get lint)" = "npx eslint" ] || fail_case "comillas dobles no retiradas"
[ "$(cd "$WS" && stack_get format-check)" = "npx prettier --check" ] || fail_case "comillas simples no retiradas"
[ -z "$(cd "$WS" && stack_get static)" ] || fail_case "clave ausente debería estar vacía"
# Desde un subdirectorio también se encuentra (raíz del repo)
mkdir -p "$WS/sub/dir"
[ "$(cd "$WS/sub/dir" && stack_get tests)" = "npm test" ] || fail_case "no se encuentra desde un subdirectorio"
# SENTINEL_STACK apunta a otro fichero
printf 'tests: make test\n' >"$WS/otro.yaml"
[ "$(cd "$WS" && SENTINEL_STACK="$WS/otro.yaml" stack_get tests)" = "make test" ] || fail_case "SENTINEL_STACK ignorado"

# Autodetección — Node: solo propone los scripts que existen en package.json
node="$WS/node-app"; mkdir -p "$node"
printf '{\n  "scripts": {\n    "test": "vitest",\n    "lint": "eslint ."\n  }\n}\n' >"$node/package.json"
out="$(stack_detect "$node")"
case "$out" in *"tests: npm test"*) ;; *) fail_case "Node: no propone tests: $out" ;; esac
case "$out" in *"lint: npm run -s lint --"*) ;; *) fail_case "Node: no propone lint: $out" ;; esac
case "$out" in *"format-check:"*[a-z]*) fail_case "Node: propone format-check sin script" ;; esac

# Autodetección — Laravel: artisan + composer.json
lara="$WS/lara-app"; mkdir -p "$lara/vendor/bin"
: >"$lara/artisan"; printf '{}\n' >"$lara/composer.json"; : >"$lara/vendor/bin/pint"
out="$(stack_detect "$lara")"
case "$out" in *"tests: php artisan test"*) ;; *) fail_case "Laravel: no propone tests: $out" ;; esac
case "$out" in *"format-check: vendor/bin/pint --test"*) ;; *) fail_case "Laravel: no propone pint: $out" ;; esac

# Stack desconocido: no inventa nada y lo dice
( stack_detect "$WS/sub" >/dev/null 2>&1 ) && fail_case "stack desconocido debería fallar"
cleanup_git_workspace
