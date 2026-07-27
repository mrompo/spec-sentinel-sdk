#!/usr/bin/env bash
# session-start — arquetipo *inject*: da contexto al agente al arrancar la sesión.
# Stdout = contexto añadido a la conversación (SessionStart hook). Nunca bloquea.
set -uo pipefail

cat >/dev/null 2>&1 || true   # el payload de SessionStart no se usa

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "sin repo git")"

# Anclaje en la raíz del proyecto (no en el cwd): en subdirectorios el contexto sería falso
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
[ -d "$ROOT/openspec" ] || ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

ACTIVE="entre fases (sin cambio OpenSpec activo)"
if [ -d "$ROOT/openspec/changes" ]; then
  names="$(find "$ROOT/openspec/changes" -mindepth 1 -maxdepth 1 -type d ! -name archive -exec basename {} \; 2>/dev/null | tr '\n' ' ')"
  [ -n "${names% }" ] && ACTIVE="cambio(s) activo(s): ${names% } — trabaja dentro y marca tasks.md"
fi

echo "[sentinel] Rama: $BRANCH · $ACTIVE · Estado: STATUS.md · Reglas: sentinel/policy.yaml"
exit 0
