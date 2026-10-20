#!/usr/bin/env bash
# SC-sentinel-guard-22: los git hooks no viajan con el clon. Si el repo tiene la Esclusa
# (sentinel/githooks/) pero en este clon no está activa ni encadenada, session-start lo avisa y
# da el comando; activa por core.hooksPath (se escriba como se escriba) o encadenada en
# .git/hooks o en husky, no avisa. Sin sentinel/githooks/, tampoco.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

START_HOOK="$REPO_ROOT/sentinel/hooks/session-start.sh"
mk_workspace
fail_case() { echo "    $1" >&2; cleanup_workspace; exit 1; }
# Sin el config global de quien ejecuta el banco (puede traer su propio core.hooksPath)
start() { RH_CWD="$WS" run_hook "$START_HOOK" '{}' CLAUDE_PROJECT_DIR="$WS" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; }
warns()   { case "$RH_OUT" in *"Esclusa"*"no está activa"*) return 0 ;; esac; return 1; }

start
assert_exit 0 || fail_case "session-start nunca debe fallar"
warns && fail_case "sin sentinel/githooks/ no hay Esclusa que avisar ($RH_OUT)"

mkdir -p "$WS/sentinel/githooks"
start
warns || fail_case "con la Esclusa en el repo pero sin activar, debería avisar (salida: $RH_OUT)"
case "$RH_OUT" in *"git config core.hooksPath sentinel/githooks"*) ;; *) fail_case "el aviso debería dar el comando que la activa";; esac

for hp in sentinel/githooks ./sentinel/githooks/ "$WS/sentinel/githooks"; do
  git -C "$WS" config core.hooksPath "$hp"
  start
  warns && fail_case "con core.hooksPath=«${hp}» la Esclusa está activa: no debería avisar"
done
# También con «~» (git lo expande): HOME de prueba con un enlace a la Esclusa (A2-8)
mkdir -p "$WS.home" && ln -s "$WS/sentinel/githooks" "$WS.home/esclusa"
git -C "$WS" config core.hooksPath "~/esclusa"
RH_CWD="$WS" run_hook "$START_HOOK" '{}' CLAUDE_PROJECT_DIR="$WS" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 HOME="$WS.home"
rm -rf "$WS.home"
warns && fail_case "con core.hooksPath=«~/esclusa» la Esclusa está activa: no debería avisar"
git -C "$WS" config --unset core.hooksPath

hd="$WS/.git/hooks"; mkdir -p "$hd"
printf '#!/bin/sh\nif [ -x sentinel/githooks/pre-commit ]; then sentinel/githooks/pre-commit "$@" || exit 1; fi\n' >"$hd/pre-commit"
chmod +x "$hd/pre-commit"
start
warns && fail_case "encadenada en .git/hooks, no debería avisar"
rm -f "$hd/pre-commit"

mkdir -p "$WS/.husky/_"
printf 'if [ -x sentinel/githooks/pre-commit ]; then sentinel/githooks/pre-commit "$@" || exit 1; fi\n' >"$WS/.husky/pre-commit"
git -C "$WS" config core.hooksPath .husky/_
start
warns && fail_case "encadenada en husky (.husky/pre-commit), no debería avisar"
rm -f "$WS/.husky/pre-commit"
start
warns || fail_case "con husky sin encadenar, debería avisar"
cleanup_workspace
