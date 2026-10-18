#!/usr/bin/env bash
# SC-sentinel-guard-13 (segunda revisión, V2-5, V2-4, V2-2): el agente no puede escribir el
# instalador (lo que ejecuta la aprobación humana de instalar), el fragmento de cableado (lo que
# la persona copia a mano) ni los hooks donde queda encadenada la Esclusa. Leerlos sí.
# Cuarta revisión (V4-4): tampoco la configuración de git donde vive core.hooksPath, la del repo
# (también de un worktree o un submódulo) y la global. Y el instalador es el del SDK, por sus dos
# rutas: una skill «setup» propia del consumidor no lo es (A4-7).
# El resto de husky y de la skill sigue siendo editable.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

fail_case() { echo "    $1" >&2; exit 1; }
guard() { run_hook "$GUARD_HOOK" "$1" SENTINEL_POLICY_DEFAULT="$DEFAULT_POLICY" SENTINEL_POLICY="$NO_POLICY"; }

for f in ai-specs/skills/setup/setup.sh ai-specs/skills/setup/chain.sh \
         /Users/me/.claude/skills/spec-sentinel-setup/setup.sh /Users/me/.claude/skills/spec-sentinel-setup/chain.sh \
         sentinel/settings.fragment.json \
         .husky/commit-msg .husky/pre-commit .husky/pre-push .git/hooks/pre-commit \
         .git/config /Users/me/app/.git/config .git/config.worktree \
         /Users/me/sdk/.git/worktrees/opah/config /Users/me/app/.git/modules/lib/config \
         /Users/me/.gitconfig /Users/me/.config/git/config; do
  guard "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$f\",\"content\":\"x\"}}"
  assert_exit 2 || fail_case "escribir $f debería bloquearse"
  guard "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$f\",\"old_string\":\"a\",\"new_string\":\"b\"}}"
  assert_exit 2 || fail_case "editar $f debería bloquearse"
  guard "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$f\"}}"
  assert_exit 0 || fail_case "leer $f no debería bloquearse"
done

for f in .husky/post-merge ai-specs/skills/setup/SKILL.md \
         .claude/skills/setup/setup.sh /Users/me/.claude/skills/setup/setup.sh; do
  guard "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$f\",\"content\":\"x\"}}"
  assert_exit 0 || fail_case "$f no está protegido: escribirlo no debería bloquearse"
done
