#!/usr/bin/env bash
# SC-sdk-setup-08 con las dos formas más comunes de tener ya git hooks:
#   a) husky v9: core.hooksPath=.husky/_ son envoltorios que husky genera (e ignora git); los
#      hooks de la persona están en .husky/<hook>. Ahí es donde se encadena la Esclusa.
#   b) hooks en .git/hooks (git-lfs, pre-commit): se encadenan donde están, sin moverlos a
#      sentinel/githooks (que setup actualiza) ni activar core.hooksPath (los silenciaría).
# En los dos: setup sale con 3 y no toca nada; con las líneas puestas, la Esclusa rechaza lo
# mismo que sola y el siguiente setup sale con 0.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

# a) husky v9 (estructura y envoltorios como los genera `husky init`, sin npm)
mk_git_workspace
mkdir -p "$WS/.husky/_"
cat >"$WS/.husky/_/h" <<'EOF'
#!/usr/bin/env sh
n=$(basename "$0")
s=$(dirname "$(dirname "$0")")/$n
[ ! -f "$s" ] && exit 0
sh -e "$s" "$@"
c=$?
exit $c
EOF
for h in commit-msg pre-commit pre-push; do
  printf '#!/usr/bin/env sh\n. "$(dirname "$0")/h"\n' >"$WS/.husky/_/$h"; chmod +x "$WS/.husky/_/$h"
done
chmod +x "$WS/.husky/_/h"; printf '*\n' >"$WS/.husky/_/.gitignore"
printf 'echo husky-pre-commit\n' >"$WS/.husky/pre-commit"   # el hook de la persona (husky v9: sin shebang)
git_in_ws config core.hooksPath .husky/_
run_setup
assert_exit 3 || fail_case "con husky debería terminar con 3"
[ "$(git_in_ws config --get core.hooksPath)" = ".husky/_" ] || fail_case "se pisó el hooksPath de husky"
assert_out_contains ".husky/pre-push" || fail_case "con husky, las líneas van en .husky/<hook>"
assert_out_lacks "hook de «.husky/_»" || fail_case "no debe proponer editar los envoltorios generados de .husky/_"
for h in commit-msg pre-commit pre-push; do
  chain_into "$WS/.husky/$h" "$h" || fail_case "no se pudo encadenar .husky/$h"
done
grep -q "husky-pre-commit" "$WS/.husky/pre-commit" || fail_case "se perdió el contenido del hook de la persona"
ws_commit "arreglado el bug"
assert_exit 1 || fail_case "encadenada en husky, la Esclusa debería rechazar un mensaje no conforme"
ws_commit "chore: la Esclusa encadenada en husky"
assert_exit 0 || fail_case "encadenada en husky, la Esclusa rechazó un commit conforme: $RH_ERR"
assert_err_contains "husky-pre-commit" || fail_case "el pre-commit de la persona dejó de ejecutarse"
gh_push HEAD:main
assert_exit 1 || fail_case "encadenada en husky, la Esclusa dejó pasar un push a main"
run_setup
assert_exit 0 || fail_case "con la Esclusa encadenada en husky, setup debería terminar con 0: $RH_ERR"
cleanup_git_workspace

# b) hooks en .git/hooks, con un pre-push que consume stdin (como git-lfs)
mk_git_workspace
hd="$(git_in_ws rev-parse --git-path hooks)"; case "$hd" in /*) ;; *) hd="$WS/$hd" ;; esac
mkdir -p "$hd"
printf '#!/bin/sh\ncat >.lfs-pre-push-saw\nexit 0\n' >"$hd/pre-push"; chmod +x "$hd/pre-push"
printf '#!/bin/sh\nexit 0\n' >"$hd/post-checkout"; chmod +x "$hd/post-checkout"
run_setup
assert_exit 3 || fail_case "con hooks propios en .git/hooks debería terminar con 3"
[ -z "$(git_in_ws config --get core.hooksPath)" ] || fail_case "no debe activarse hooksPath: dejaría mudos los hooks propios"
assert_out_contains "pre-push" || fail_case "la salida no nombra el hook propio afectado"
assert_out_contains 'sentinel/githooks/pre-push "$@"' || fail_case "la salida no da las líneas de encadenado"
assert_out_lacks "Muévelos" || fail_case "no debe proponer mover los hooks a sentinel/githooks (setup los sobrescribe)"
for h in commit-msg pre-commit pre-push; do
  chain_into "$hd/$h" "$h" || fail_case "no se pudo encadenar $h en .git/hooks"
done
ws_commit "arreglado el bug"
assert_exit 1 || fail_case "encadenada en .git/hooks, la Esclusa debería rechazar un mensaje no conforme"
gh_push HEAD:main
assert_exit 1 || fail_case "encadenada en .git/hooks, la Esclusa dejó pasar un push a main"
gh_push HEAD:feature/fixture
assert_exit 0 || fail_case "encadenada en .git/hooks, la Esclusa rechazó un push a una rama feature: $RH_ERR"
grep -q "refs/heads/feature/fixture" "$WS/.lfs-pre-push-saw" || fail_case "el pre-push de LFS no recibió las refs tras la Esclusa"
run_setup
assert_exit 0 || fail_case "con la Esclusa encadenada en .git/hooks, setup debería terminar con 0: $RH_ERR"
[ -z "$(git_in_ws config --get core.hooksPath)" ] || fail_case "encadenada en .git/hooks, setup no debe activar hooksPath"
cleanup_git_workspace
