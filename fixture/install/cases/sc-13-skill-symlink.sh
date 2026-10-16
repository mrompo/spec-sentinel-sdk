#!/usr/bin/env bash
# SC-sdk-setup-13: la guía propone exponer la skill con un enlace simbólico a su carpeta
# (~/.claude/skills/setup). Ejecutado a través del enlace, setup encuentra el SDK real e instala
# igual (A2-5 = P2-6).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
# Donde lo pone la guía: <HOME>/.claude/skills/setup (subir tres niveles desde ahí no lleva al SDK)
home="$WS.home"; link="$home/.claude/skills/setup"
fail_case() { echo "    $1" >&2; rm -rf "$home"; cleanup_git_workspace; exit 1; }
mkdir -p "$home/.claude/skills" && ln -s "$REPO_ROOT/ai-specs/skills/setup" "$link" || fail_case "no se pudo crear el enlace"

_capture env "$(gl_ok)" bash "$link/setup.sh" "$WS"
assert_exit 0 || fail_case "a través del enlace a la skill, setup debería instalar y terminar con 0"
[ -f "$WS/sentinel/hooks/sentinel-guard.sh" ] || fail_case "a través del enlace no se instaló el enforcement"
[ "$(git_in_ws config --get core.hooksPath)" = "sentinel/githooks" ] || fail_case "a través del enlace no se activó la Esclusa"

rm -rf "$home"
cleanup_git_workspace
