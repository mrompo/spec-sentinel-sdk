#!/usr/bin/env bash
# post-edit — arquetipo *auto-fix*: formatea el fichero editado con el comando `format`
# del adaptador de stack (sentinel.yaml). Degradación silenciosa: sin adaptador, sin
# comando o con error de formateo, nunca falla ni bloquea (PostToolUse).
set -uo pipefail

PAYLOAD="$(cat || true)"
FILE_PATH="$(printf '%s' "$PAYLOAD" | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1)"
[ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ] || exit 0

CFG="${SENTINEL_STACK:-sentinel.yaml}"
if [ ! -f "$CFG" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  CFG="$root/sentinel.yaml"
fi
[ -f "$CFG" ] || exit 0

FMT="$(sed -nE 's/^format:[[:space:]]*//p' "$CFG" | head -1)"
[ -n "$FMT" ] || exit 0

$FMT "$FILE_PATH" >/dev/null 2>&1 || true
exit 0
