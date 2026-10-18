#!/usr/bin/env bash
# SC-sdk-setup-13: la guía propone exponer la skill con un enlace simbólico a su carpeta, con un
# nombre propio (~/.claude/skills/spec-sentinel-setup). Ejecutado a través del enlace, setup
# encuentra el SDK real e instala igual (A2-5 = P2-6). La orden de la guía crea la carpeta de
# skills si falta y, repetida, no anida un enlace dentro del SDK (P4-5).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
# Donde lo pone la guía: <HOME>/.claude/skills/spec-sentinel-setup (subir tres niveles desde ahí no
# lleva al SDK). <HOME>/.claude/skills no existe todavía
home="$WS.home"; link="$home/.claude/skills/spec-sentinel-setup"; nested="$REPO_ROOT/ai-specs/skills/setup/setup"
fail_case() { echo "    $1" >&2; rm -rf "$home"; [ -L "$nested" ] && rm -f "$nested"; cleanup_git_workspace; exit 1; }
mkdir -p "$home"
for _ in 1 2; do
  ( HOME="$home" && mkdir -p "$HOME/.claude/skills" \
      && ln -sfn "$REPO_ROOT/ai-specs/skills/setup" "$HOME/.claude/skills/spec-sentinel-setup" ) \
    || fail_case "la orden de la guía para enlazar la skill falló"
done
[ -L "$nested" ] && fail_case "repetir la orden de la guía anidó un enlace dentro del SDK"
[ "$(cd -P "$link" && pwd -P)" = "$(cd -P "$REPO_ROOT/ai-specs/skills/setup" && pwd -P)" ] \
  || fail_case "el enlace no apunta a la skill del SDK"

_capture env "$(gl_ok)" bash "$link/setup.sh" "$WS"
assert_exit 0 || fail_case "a través del enlace a la skill, setup debería instalar y terminar con 0: $RH_ERR"
[ -f "$WS/sentinel/hooks/sentinel-guard.sh" ] || fail_case "a través del enlace no se instaló el enforcement"
[ "$(git_in_ws config --get core.hooksPath)" = "sentinel/githooks" ] || fail_case "a través del enlace no se activó la Esclusa"

# El nombre de la skill es el del enlace
grep -qx "name: spec-sentinel-setup" "$REPO_ROOT/ai-specs/skills/setup/SKILL.md" \
  || fail_case "la skill debería llamarse como su enlace (name: spec-sentinel-setup)"

rm -rf "$home"
cleanup_git_workspace
