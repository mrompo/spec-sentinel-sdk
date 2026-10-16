#!/usr/bin/env bash
# SC-sdk-setup-08: si el consumidor ya usa otros git hooks (un hooksPath propio o hooks en el
# directorio de hooks de git), setup no cambia core.hooksPath: termina con 3 y explica cómo
# encadenar la Esclusa a mano. El resto de la instalación sí se completa. Si ese hooksPath no
# tiene hooks en el repo, no hay nada que encadenar: lo dice y da el comando que la activa.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

# a) core.hooksPath propio con hooks (p. ej. husky)
git_in_ws config core.hooksPath .husky
mkdir -p "$WS/.husky"; printf '#!/bin/sh\nexit 0\n' >"$WS/.husky/pre-commit"; chmod +x "$WS/.husky/pre-commit"
run_setup
assert_exit 3 || fail_case "con un hooksPath propio debería terminar con 3"
[ "$(git_in_ws config --get core.hooksPath)" = ".husky" ] || fail_case "se pisó el hooksPath del consumidor"
assert_out_contains "Encadena la Esclusa" || fail_case "la salida no explica cómo encadenar la Esclusa"
assert_out_contains "sentinel/githooks/<hook>" || fail_case "la salida no da la línea que encadena"
[ -f "$WS/.claude/settings.json" ] || fail_case "el Centinela debe quedar cableado igualmente"
cleanup_git_workspace

# a2) core.hooksPath global y relativo cuya carpeta no existe en este repo: no ejecuta nada aquí
mk_git_workspace
gcfg="$WS.gitconfig"; printf '[core]\n\thooksPath = .githooks\n' >"$gcfg"
run_setup GIT_CONFIG_GLOBAL="$gcfg"
assert_exit 3 || { rm -f "$gcfg"; fail_case "con un hooksPath global debería terminar con 3"; }
[ -z "$(git_in_ws config --local --get core.hooksPath)" ] || { rm -f "$gcfg"; fail_case "setup no debe cambiar core.hooksPath"; }
assert_out_contains "no tiene hooks en este repo" || { rm -f "$gcfg"; fail_case "no dice que ese hooksPath no ejecuta nada aquí"; }
assert_out_contains "git config core.hooksPath sentinel/githooks" || { rm -f "$gcfg"; fail_case "no da el comando que activa la Esclusa"; }
! printf '%s' "$RH_ERR" | grep -q "Encadena" || { rm -f "$gcfg"; fail_case "propone encadenar hooks que no existen"; }
rm -f "$gcfg"
cleanup_git_workspace

# b) hooks propios en el directorio de hooks de git (los .sample no cuentan)
mk_git_workspace
hooks_dir="$(git_in_ws rev-parse --git-path hooks)"
case "$hooks_dir" in /*) ;; *) hooks_dir="$WS/$hooks_dir" ;; esac
mkdir -p "$hooks_dir"; printf '#!/bin/sh\nexit 0\n' >"$hooks_dir/pre-commit"; chmod +x "$hooks_dir/pre-commit"
run_setup
assert_exit 3 || fail_case "con hooks propios en .git/hooks debería terminar con 3"
[ -z "$(git_in_ws config --get core.hooksPath)" ] || fail_case "no debe activarse hooksPath: dejaría mudos los hooks propios"
assert_out_contains "pre-commit" || fail_case "la salida no nombra el hook propio afectado"
cleanup_git_workspace
