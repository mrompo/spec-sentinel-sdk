#!/usr/bin/env bash
# SC-git-gates-11: la llave (sentinel/.override con motivo) salta UN rechazo de la Esclusa, lo
# registra en la bitácora con hook y motivo, y se consume. Sin llave, el rechazo dice cómo pedirla.
# Un motivo solo de espacios no vale.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
mkdir -p "$WS/sentinel"
TOKEN="$WS/sentinel/.override"; LOG="$WS/sentinel/overrides.log"

# Sin llave: rechazo normal, con la pista de la excepción, y bitácora intacta
gh_commit "arreglado el bug"
assert_exit 1 || fail_case "sin llave debería rechazar"
assert_err_contains "sentinel/.override" || fail_case "el rechazo no dice cómo pedir la excepción"
[ ! -e "$LOG" ] || fail_case "sin llave no debería escribirse la bitácora"

# Motivo solo de espacios: no vale, y no se consume ni se registra
printf '   \n' >"$TOKEN"
gh_commit "arreglado el bug"
assert_exit 1 || fail_case "un motivo vacío no debería valer"
[ ! -e "$LOG" ] || fail_case "un motivo vacío no debería registrarse"
rm -f "$TOKEN"

# Con llave: el commit entra, queda registrado y la llave desaparece
printf 'hotfix INC-9 aprobado por tech lead\n' >"$TOKEN"
gh_commit "arreglado el bug"
assert_exit 0 || fail_case "con llave el commit debería entrar"
assert_err_contains "auditado" || fail_case "no avisa de que la excepción queda auditada"
[ ! -e "$TOKEN" ] || fail_case "la llave no se consumió"
grep -q "esclusa:commit-msg" "$LOG" 2>/dev/null || fail_case "la bitácora no nombra el hook"
grep -q "INC-9" "$LOG" 2>/dev/null || fail_case "la bitácora no tiene el motivo"
[ "$(wc -l <"$LOG" | tr -d ' ')" = "1" ] || fail_case "debería haber exactamente una línea en la bitácora"

# Un solo uso: el siguiente rechazo vuelve a bloquear
gh_commit "otro sin formato"
assert_exit 1 || fail_case "la llave debería ser de un solo uso"

# También vale para pre-push (rama protegida), con su propio registro
printf 'hotfix INC-10 directo a main\n' >"$TOKEN"
gh_push HEAD:main
assert_exit 0 || fail_case "con llave el push a main debería entrar"
grep -q "esclusa:pre-push" "$LOG" 2>/dev/null || fail_case "la bitácora no registra el pre-push"
grep -q "INC-10" "$LOG" 2>/dev/null || fail_case "la bitácora no tiene el motivo del push"
cleanup_git_workspace
