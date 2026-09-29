#!/usr/bin/env bash
# SC-git-gates-08: entorno mal configurado (env-ready falla) → fallo duro con la instrucción
# exacta de arreglo (env-fix); nunca skip. Sin env-fix, se dice qué comando lo comprueba.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
mkdir -p "$WS/sentinel/adapters"
printf 'limpio\n' >"$WS/a.txt"; git_in_ws add a.txt

cat >"$WS/sentinel/adapters/stack.yaml" <<'EOF'
env-ready: false
env-fix: docker compose up -d app
lint: true
EOF
_capture env SENTINEL_GITLEAKS_BIN=/nonexistent/gitleaks git commit -q -m "feat: a"
assert_exit 1 || fail_case "con el entorno roto el commit no debería entrar"
assert_err_contains "docker compose up -d app" || fail_case "no muestra la instrucción de arreglo"
case "$RH_ERR" in *"se omiten env-ready"*|*"sin adaptador"*) fail_case "un entorno roto no es un skip" ;; esac

# Sin env-fix: el mensaje nombra el comando que comprueba el entorno
printf 'env-ready: false\n' >"$WS/sentinel/adapters/stack.yaml"
_capture env SENTINEL_GITLEAKS_BIN=/nonexistent/gitleaks git commit -q -m "feat: a"
assert_exit 1 || fail_case "sin env-fix también es fallo duro"
assert_err_contains "env-ready" || fail_case "no nombra el comando env-ready"

# Entorno listo → pasa
printf 'env-ready: true\n' >"$WS/sentinel/adapters/stack.yaml"
_capture env SENTINEL_GITLEAKS_BIN=/nonexistent/gitleaks git commit -q -m "feat: a"
assert_exit 0 || fail_case "con el entorno listo debería entrar"
cleanup_git_workspace
