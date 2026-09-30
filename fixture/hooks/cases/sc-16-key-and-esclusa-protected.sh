#!/usr/bin/env bash
# SC-git-gates-14: el agente no puede crear la llave (sentinel/.override): el break-glass lo
#   concede una persona, nunca el propio agente.
# SC-git-gates-15: el agente no puede desarmar la Esclusa (hooks, su librería, el lector del
#   adaptador) ni saltar sus comprobaciones con las variables de prueba. Los ficheros del
#   consumidor y la documentación siguen siendo editables.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$REPO_ROOT/sentinel/policy.yaml"

# Deben bloquearse (exit 2)
while IFS= read -r payload; do
  [ -n "$payload" ] || continue
  run_hook "$GUARD_HOOK" "$payload" SENTINEL_POLICY="$P"
  assert_exit 2 || { echo "    debería bloquearse: $payload" >&2; exit 1; }
done <<'EOF'
{"tool_name":"Write","tool_input":{"file_path":"sentinel/.override","content":"motivo"}}
{"tool_name":"Bash","tool_input":{"command":"echo motivo > sentinel/.override"}}
{"tool_name":"Bash","tool_input":{"command":"printf x | tee sentinel/.override"}}
{"tool_name":"Write","tool_input":{"file_path":"sentinel/githooks/pre-commit","content":"exit 0"}}
{"tool_name":"Edit","tool_input":{"file_path":"sentinel/githooks/commit-msg","new_string":"exit 0"}}
{"tool_name":"Write","tool_input":{"file_path":"sentinel/githooks/pre-push","content":"exit 0"}}
{"tool_name":"Edit","tool_input":{"file_path":"sentinel/githooks/lib/breakglass.sh","new_string":"exit 0"}}
{"tool_name":"Write","tool_input":{"file_path":"sentinel/adapters/stack.sh","content":"stack_get() { :; }"}}
{"tool_name":"Bash","tool_input":{"command":"rm sentinel/githooks/commit-msg"}}
{"tool_name":"Bash","tool_input":{"command":"SENTINEL_GITLEAKS_BIN=/tmp/ok git commit -m x"}}
{"tool_name":"Bash","tool_input":{"command":"SENTINEL_OPENSPEC_BIN=/tmp/ok git push"}}
{"tool_name":"Bash","tool_input":{"command":"SENTINEL_STACK=/dev/null git commit -m x"}}
EOF

# Deben seguir permitidos (exit 0): ficheros del consumidor y documentación
while IFS= read -r payload; do
  [ -n "$payload" ] || continue
  run_hook "$GUARD_HOOK" "$payload" SENTINEL_POLICY="$P"
  assert_exit 0 || { echo "    debería permitirse: $payload" >&2; exit 1; }
done <<'EOF'
{"tool_name":"Write","tool_input":{"file_path":"sentinel/adapters/stack.yaml","content":"tests: npm test"}}
{"tool_name":"Edit","tool_input":{"file_path":"sentinel/githooks/README.md","new_string":"doc"}}
{"tool_name":"Edit","tool_input":{"file_path":"sentinel/adapters/README.md","new_string":"doc"}}
EOF
exit 0
