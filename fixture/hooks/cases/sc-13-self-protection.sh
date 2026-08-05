#!/usr/bin/env bash
# SC-sentinel-guard-13 (hallazgo #1 del panel adversarial): el guard no se desarma a sí mismo.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$REPO_ROOT/sentinel/policy.yaml"

# Escribir la política, el hook, el log o el cableado → block
for payload in \
  '{"tool_name":"Write","tool_input":{"file_path":"sentinel/policy.yaml","content":"version: 1\nrules:\n"}}' \
  '{"tool_name":"Write","tool_input":{"file_path":"sentinel/hooks/sentinel-guard.sh","content":"exit 0"}}' \
  '{"tool_name":"Write","tool_input":{"file_path":".claude/settings.json","content":"{}"}}' \
  '{"tool_name":"Edit","tool_input":{"file_path":"sentinel/overrides.log","new_string":""}}' ; do
  run_hook "$GUARD_HOOK" "$payload" SENTINEL_POLICY="$P"
  assert_exit 2 || { echo "    payload: $payload" >&2; exit 1; }
done

# Borrarlo o desactivarlo desde shell → block
for cmd in "rm sentinel/hooks/sentinel-guard.sh" "git commit --no-verify -m x" "git config core.hooksPath /dev/null" "echo x > .claude/settings.json"; do
  run_hook "$GUARD_HOOK" "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}" SENTINEL_POLICY="$P"
  assert_exit 2 || { echo "    cmd: $cmd" >&2; exit 1; }
done
exit 0
