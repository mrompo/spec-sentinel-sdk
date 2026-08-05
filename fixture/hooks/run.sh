#!/usr/bin/env bash
# Ejecuta todos los casos del runner de hooks (uno por escenario SC-sentinel-guard-*).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pass=0; failed=0
for c in "$DIR"/cases/*.sh; do
  name="$(basename "$c" .sh)"
  if bash "$c"; then
    echo "✓ hooks/$name"; pass=$((pass+1))
  else
    echo "✗ hooks/$name" >&2; failed=$((failed+1))
  fi
done
echo "— hooks: $pass ok, $failed fallos"
[ "$failed" -eq 0 ]
