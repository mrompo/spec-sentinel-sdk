#!/usr/bin/env bash
# Ejecuta todos los casos del runner de git hooks (uno por escenario SC-git-gates-*).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pass=0; failed=0
for c in "$DIR"/cases/*.sh; do
  name="$(basename "$c" .sh)"
  if bash "$c"; then
    echo "✓ githooks/$name"; pass=$((pass+1))
  else
    echo "✗ githooks/$name" >&2; failed=$((failed+1))
  fi
done
echo "— githooks: $pass ok, $failed fallos"
[ "$failed" -eq 0 ]
