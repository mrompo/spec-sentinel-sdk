#!/usr/bin/env bash
# SC-sdk-setup-12 (revisión de sentinel-paths, P1): la prueba de humo de setup lanza el Centinela
# con su cableado, tal como queda en .claude/settings.json, y no solo el script: si en esta
# máquina el cableado no deja pasar una acción inocua (p. ej. no encuentra git en su PATH fijo),
# setup termina con 3 y muestra lo que dice el cableado.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

SDK="$(mktemp -d)"
fail_case() { echo "    $1" >&2; rm -rf "$SDK"; cleanup_git_workspace; exit 1; }

# Una copia del SDK cuyo cableado lleva un PATH donde no hay nada: como una máquina con git fuera
# del PATH fijo, el cableado bloquea todo, mientras que el Centinela solo deja pasar lo inocuo
( cd "$REPO_ROOT" && git ls-files -z | tar --null -T - -cf - ) | ( cd "$SDK" && tar -xf - )
jq '(.hooks.PreToolUse[].hooks[] | select(.command | contains("sentinel/hooks/sentinel-guard.sh")) | .command)
      |= sub("PATH=/usr/bin:/bin:[^ ]*"; "PATH=/nonexistent")' \
  "$REPO_ROOT/.claude/settings.json" >"$SDK/.claude/settings.json"
grep -q 'PATH=/nonexistent' "$SDK/.claude/settings.json" || fail_case "no se pudo cambiar el cableado de la copia"

mk_git_workspace
_capture env "$(gl_ok)" bash "$SDK/ai-specs/skills/setup/setup.sh" "$WS"
assert_exit 3 || fail_case "con un cableado que no deja pasar nada, setup debería terminar con 3 (exit $RH_EXIT): $RH_ERR"
assert_out_contains "no deja pasar una acción inocua" || fail_case "setup debería decir que lo que falla es el cableado: $RH_ERR"
assert_out_lacks "deniega una acción inocua" || fail_case "setup no debería achacárselo al Centinela: $RH_ERR"
rm -rf "$SDK"; cleanup_git_workspace
