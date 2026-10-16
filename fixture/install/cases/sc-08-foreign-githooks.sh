#!/usr/bin/env bash
# SC-sdk-setup-08: si el consumidor ya usa otros git hooks, setup no los toca ni cambia
# core.hooksPath: sale con 3 y da las líneas que encadenan la Esclusa al principio de sus hooks.
# Con ellas puestas, la Esclusa rechaza lo mismo que sola, el resto del hook sigue recibiendo las
# refs de stdin, los repos sin la Esclusa no se rompen y el siguiente setup sale con 0. Un
# hooksPath sin hooks aquí no se encadena, y uno que ya apunta a la Esclusa cuenta como activo.
# (husky v9 y .git/hooks: sc-10.)
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

# a) hooksPath propio con un pre-push que consume stdin (como `git lfs pre-push`)
mk_git_workspace
git_in_ws config core.hooksPath .githooks-own
mkdir -p "$WS/.githooks-own"
printf '#!/bin/sh\ncat >.own-pre-push-saw\nexit 0\n' >"$WS/.githooks-own/pre-push"
chmod +x "$WS/.githooks-own/pre-push"
run_setup
assert_exit 3 || fail_case "con un hooksPath propio debería terminar con 3"
[ "$(git_in_ws config --get core.hooksPath)" = ".githooks-own" ] || fail_case "se pisó el hooksPath del consumidor"
assert_out_contains 'sentinel/githooks/pre-push "$@"' || fail_case "la salida no da las líneas de encadenado"
assert_out_contains "al principio" || fail_case "la salida no dice dónde van las líneas"
assert_out_lacks "Muévelos" || fail_case "no debe proponer mover hooks a sentinel/githooks"
for h in commit-msg pre-commit pre-push; do
  chain_into "$WS/.githooks-own/$h" "$h" || fail_case "no se pudo encadenar $h"
done
git_in_ws add -A -- . ':!.gl-ok'
ws_commit "arreglado el bug"
assert_exit 1 || fail_case "encadenada, la Esclusa debería rechazar un mensaje no conforme"
ws_commit "chore: la Esclusa encadenada"
assert_exit 0 || fail_case "encadenada, la Esclusa rechazó un commit conforme: $RH_ERR"
gh_push HEAD:main
assert_exit 1 || fail_case "encadenada en un pre-push que consume stdin, la Esclusa dejó pasar un push a main"
gh_push HEAD:feature/fixture
assert_exit 0 || fail_case "encadenada, la Esclusa rechazó un push a una rama feature: $RH_ERR"
grep -q "refs/heads/feature/fixture" "$WS/.own-pre-push-saw" || fail_case "el pre-push propio no recibió las refs tras la Esclusa"
run_setup
assert_exit 0 || fail_case "con la Esclusa encadenada, setup debería terminar con 0: $RH_ERR"
assert_out_contains "encadenada" || fail_case "setup no reconoce el encadenado"
cleanup_git_workspace

# b) hooksPath global y relativo cuya carpeta no existe en este repo: no ejecuta nada aquí
mk_git_workspace
gcfg="$WS.gitconfig"; printf '[core]\n\thooksPath = .githooks\n' >"$gcfg"
run_setup GIT_CONFIG_GLOBAL="$gcfg"
assert_exit 3 || { rm -f "$gcfg"; fail_case "con un hooksPath global debería terminar con 3"; }
[ -z "$(git_in_ws config --local --get core.hooksPath)" ] || { rm -f "$gcfg"; fail_case "setup no debe cambiar core.hooksPath"; }
assert_out_contains "no tiene hooks en este repo" || { rm -f "$gcfg"; fail_case "no dice que ese hooksPath no ejecuta nada aquí"; }
assert_out_contains "git config core.hooksPath sentinel/githooks" || { rm -f "$gcfg"; fail_case "no da el comando que activa la Esclusa"; }
assert_out_lacks "Encadena" || { rm -f "$gcfg"; fail_case "propone encadenar hooks que no existen"; }
rm -f "$gcfg"
cleanup_git_workspace

# c) hooksPath global con hooks (un escáner corporativo): las líneas no rompen los demás repos
mk_git_workspace
corp="$WS.corp"; other="$WS.other"; gcfg="$WS.gitconfig"
done_c() { rm -rf "$corp" "$other" "$gcfg"; }
mkdir -p "$corp"; printf '#!/bin/sh\nexit 0\n' >"$corp/pre-commit"; chmod +x "$corp/pre-commit"
printf '[core]\n\thooksPath = %s\n' "$corp" >"$gcfg"
run_setup GIT_CONFIG_GLOBAL="$gcfg"
assert_exit 3 || { done_c; fail_case "con un hooksPath global con hooks debería terminar con 3"; }
for h in commit-msg pre-commit pre-push; do chain_into "$corp/$h" "$h" || { done_c; fail_case "no se pudo encadenar $h"; }; done
git init -q "$other"
_capture env GIT_CONFIG_GLOBAL="$gcfg" git -C "$other" commit -q --allow-empty -m "cualquier cosa"
assert_exit 0 || { done_c; fail_case "las líneas de encadenado rompen los commits de un repo sin la Esclusa: $RH_ERR"; }
_capture env "$(gl_ok)" GIT_CONFIG_GLOBAL="$gcfg" git commit -q --allow-empty -m "arreglado"
assert_exit 1 || { done_c; fail_case "encadenada en el hooksPath global, la Esclusa no rechazó un mensaje no conforme"; }
run_setup GIT_CONFIG_GLOBAL="$gcfg"
assert_exit 0 || { done_c; fail_case "con la Esclusa encadenada en el hooksPath global, setup debería terminar con 0: $RH_ERR"; }
done_c
cleanup_git_workspace

# d) un hooksPath que ya apunta a la Esclusa, escrito de otra forma, cuenta como activo
mk_git_workspace
run_setup
assert_exit 0 || fail_case "la instalación en un repo limpio debería terminar con 0"
for hp in "./sentinel/githooks" "sentinel/githooks/" "$WS/sentinel/githooks"; do
  git_in_ws config core.hooksPath "$hp"
  run_setup
  assert_exit 0 || fail_case "con core.hooksPath=«${hp}» la Esclusa ya está activa: debería terminar con 0"
  assert_out_lacks "PENDIENTE" || fail_case "con core.hooksPath=«${hp}» no debería quedar nada pendiente"
done
cleanup_git_workspace
