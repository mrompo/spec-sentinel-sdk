#!/usr/bin/env bash
# SC-git-gates-11: la llave (sentinel/.override con motivo) salta UN rechazo de la Esclusa, lo
# registra en la bitácora con hook y motivo, y se consume. Sin llave, el rechazo dice cómo pedirla,
# y pegada tal cual en una shell la escribe (revisión de sentinel-paths, P4 = A6). Un motivo solo
# de espacios no vale.
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

# sentinel-paths: la llave se ata a un hook. Una llave sin para:, atada a otro hook o a una
# acción del Centinela no salta el rechazo, se conserva, y el mensaje da la de este hook
for llave in 'hotfix INC-9\n' 'hotfix INC-9\npara: esclusa:pre-commit\n' 'hotfix INC-9\npara: Write:sentinel/policy.yaml\n'; do
  printf "$llave" >"$TOKEN"
  gh_commit "arreglado el bug"
  assert_exit 1 || fail_case "una llave que no es de commit-msg no debería valer: $llave"
  [ -s "$TOKEN" ] || fail_case "una llave que no es de commit-msg no debería gastarse: $llave"
  assert_err_contains "para: esclusa:commit-msg" || fail_case "el rechazo no da la llave de este hook"
  [ ! -e "$LOG" ] || fail_case "una llave que no vale no debería registrarse"
done
rm -f "$TOKEN"

# Con llave: el commit entra, queda registrado y la llave desaparece
printf 'hotfix INC-9 aprobado por tech lead\npara: esclusa:commit-msg\n' >"$TOKEN"
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
printf 'hotfix INC-10 directo a main\npara: esclusa:pre-push\n' >"$TOKEN"
gh_push HEAD:main
assert_exit 0 || fail_case "con llave el push a main debería entrar"
grep -q "esclusa:pre-push" "$LOG" 2>/dev/null || fail_case "la bitácora no registra el pre-push"
grep -q "INC-10" "$LOG" 2>/dev/null || fail_case "la bitácora no tiene el motivo del push"

# paste_key <aviso> <shell> → copia del aviso las líneas de la llave tal como salen (de la que la
# escribe a la que la cierra), pone el motivo y las pega en esa shell, desde una subcarpeta del
# workspace: una persona no tiene por qué estar en la raíz
paste_key() {
  printf '%s\n' "$1" | sed -n "/^cat > .*<<'LLAVE'\$/,/^[[:space:]]*LLAVE/p" \
    | sed 's/<motivo>/arreglo aprobado/' >"$WS.pegar"
  [ -s "$WS.pegar" ] || return 1
  mkdir -p "$WS/src/sub"
  ( cd "$WS/src/sub" && "$2" "$WS.pegar" </dev/null >/dev/null 2>&1 ); rm -f "$WS.pegar"
}
# Un repo en una carpeta con espacios y comillas: la llave pegada va a su sitio igual
NEW="$WS-la 'llave' \$x"; mv "$WS" "$NEW"; mv "$WS.remote" "$NEW.remote"; WS="$NEW"
TOKEN="$WS/sentinel/.override"; LOG="$WS/sentinel/overrides.log"
# La llave del rechazo, pegada tal cual en bash o en sh desde una subcarpeta, queda en la raíz
# del repo con el motivo y el para: del hook, y salta ese rechazo (revisión de la #18)
for sh in bash sh; do
  gh_commit "otro sin formato"
  assert_exit 1 || fail_case "sin llave debería rechazar"
  paste_key "$RH_ERR" "$sh" || fail_case "el rechazo no trae la llave"
  [ "$(cat "$TOKEN" 2>/dev/null)" = "$(printf 'arreglo aprobado\npara: esclusa:commit-msg')" ] \
    || fail_case "la llave pegada en $sh debería quedar con el motivo y el para:: $(cat "$TOKEN" 2>/dev/null)"
  gh_commit "otro sin formato"
  assert_exit 0 || fail_case "con la llave pegada en $sh, el commit debería entrar"
done
cleanup_git_workspace
