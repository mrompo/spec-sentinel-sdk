#!/usr/bin/env bash
# Ejecuta todos los casos del runner de instalación (uno por escenario SC-sdk-setup-*).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pass=0; failed=0
for c in "$DIR"/cases/*.sh; do
  name="$(basename "$c" .sh)"
  if bash "$c"; then
    echo "✓ install/$name"; pass=$((pass+1))
  else
    echo "✗ install/$name" >&2; failed=$((failed+1))
  fi
done
echo "— install: $pass ok, $failed fallos"
[ "$failed" -eq 0 ]
