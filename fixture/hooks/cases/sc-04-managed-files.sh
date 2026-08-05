#!/usr/bin/env bash
# SC-sentinel-guard-04: editar CHANGELOG / lockfile / specs archivadas → block
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

for path in "CHANGELOG.md" "package-lock.json" "openspec/specs/sdk-method/spec.md"; do
  run_hook "$GUARD_HOOK" \
    "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$path\",\"new_string\":\"x\"}}" \
    SENTINEL_POLICY="$REPO_ROOT/sentinel/policy.yaml"
  assert_exit 2 || exit 1
  assert_err_contains "gestionado" || exit 1
done

# Un fichero normal pasa
run_hook "$GUARD_HOOK" \
  '{"tool_name":"Edit","tool_input":{"file_path":"docs/guia-uso.md","new_string":"x"}}' \
  SENTINEL_POLICY="$REPO_ROOT/sentinel/policy.yaml"
assert_exit 0
