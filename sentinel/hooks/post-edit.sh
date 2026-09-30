#!/usr/bin/env bash
# post-edit — arquetipo *auto-fix*: formatea el fichero editado con el comando `format`
# del adaptador de stack (sentinel/adapters/stack.yaml, leído con adapters/stack.sh: el mismo
# lector que la Esclusa). Degradación silenciosa: sin adaptador, sin comando o con error de
# formateo, nunca falla ni bloquea (PostToolUse).
set -uo pipefail

PAYLOAD="$(cat || true)"
FILE_PATH="$(printf '%s' "$PAYLOAD" | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1)"
[ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ] || exit 0

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/../adapters/stack.sh" 2>/dev/null || exit 0
FMT="$(stack_get format)"
[ -n "$FMT" ] || exit 0

$FMT "$FILE_PATH" >/dev/null 2>&1 || true
exit 0
