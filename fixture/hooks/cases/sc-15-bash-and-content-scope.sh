#!/usr/bin/env bash
# SC-sentinel-guard-15: las reglas de ruta alcanzan a Bash, y content_re solo mira lo escrito.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$REPO_ROOT/sentinel/policy.yaml"
rc=0

# a) Tocar ficheros gestionados desde shell (sin file_path) → block
for cmd in "sed -i '' s/x/y/ CHANGELOG.md" "echo x >> CHANGELOG.md" "cat .env.production"; do
  run_hook "$GUARD_HOOK" "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}" SENTINEL_POLICY="$P"
  assert_exit 2 || { echo "    cmd: $cmd" >&2; rc=1; }
done

# b) QUITAR un .skip existente debe PERMITIRSE (old_string no cuenta como contenido escrito)
run_hook "$GUARD_HOOK" \
  '{"tool_name":"Edit","tool_input":{"file_path":"tests/u.test.js","old_string":"describe.skip(\"a\")","new_string":"describe(\"a\")"}}' \
  SENTINEL_POLICY="$P"
assert_exit 0 || { echo "    reparar un test no debe bloquearse" >&2; rc=1; }

# c) Documentar la regla en un .md del repo (cuya ruta contiene 'spec') debe PERMITIRSE
run_hook "$GUARD_HOOK" \
  '{"tool_name":"Edit","tool_input":{"file_path":"docs/guia-uso.md","new_string":"ejemplo: no uses it.only( en tests"}}' \
  SENTINEL_POLICY="$P"
assert_exit 0 || { echo "    escribir docs no debe bloquearse" >&2; rc=1; }

# d) Rutas equivalentes (./ y ../) al mismo fichero protegido → block
run_hook "$GUARD_HOOK" \
  '{"tool_name":"Edit","tool_input":{"file_path":"openspec/changes/../specs/sdk-method/spec.md","new_string":"x"}}' \
  SENTINEL_POLICY="$P"
assert_exit 2 || { echo "    ruta con ../ debe bloquearse" >&2; rc=1; }
exit $rc
