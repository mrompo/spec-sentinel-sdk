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

echo "[sentinel] Rama: $BRANCH · $ACTIVE · Estado: STATUS.md · Reglas: sentinel/policy.default.yaml (SDK) + sentinel/policy.yaml (proyecto)"

# Los git hooks no viajan con el clon: si el repo tiene la Esclusa pero aquí no está activa ni
# encadenada (p. ej. un clon recién hecho), se avisa (SC-sentinel-guard-22)
if [ -d "$ROOT/sentinel/githooks" ]; then
  hp="$(git -C "$ROOT" config --get core.hooksPath 2>/dev/null || true)"; hp="${hp%/}"; hp="${hp#./}"
  esclusa=0
  case "$hp" in
    sentinel/githooks) esclusa=1 ;;
    /*) [ -d "$hp" ] && [ "$(cd "$hp" && pwd -P)" = "$(cd "$ROOT/sentinel/githooks" && pwd -P)" ] && esclusa=1 ;;
  esac
  if [ "$esclusa" -eq 0 ]; then
    # ¿Encadenada en los hooks que git ejecuta? (con husky v9, los de la persona están en .husky/)
    hd="$(git -C "$ROOT" rev-parse --git-path hooks 2>/dev/null || true)"; hd="${hd%/}"
    case "$hd" in /*) ;; *) hd="$ROOT/$hd" ;; esac
    case "$hd" in */.husky/_) hd="${hd%/_}" ;; esac
    grep -qsF 'sentinel/githooks/pre-commit "$@"' "$hd/pre-commit" && esclusa=1
  fi
  [ "$esclusa" -eq 1 ] || echo "[sentinel] ⚠ La Esclusa (git hooks) no está activa en este clon: actívala con «git config core.hooksPath sentinel/githooks» o ejecuta setup"
fi
exit 0
