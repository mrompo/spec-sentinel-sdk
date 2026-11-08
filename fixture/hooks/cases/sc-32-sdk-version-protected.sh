#!/usr/bin/env bash
# SC-sdk-version-08: la versión del SDK instalada (sentinel/.sdk-version) es enforcement. Si el
# agente pudiera reescribirla, una copia vieja del SDK pasaría por la misma versión y setup la
# instalaría sin pedir confirmación. Leerla no se bloquea.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$DEFAULT_POLICY"

# Escribirla con las herramientas de edición → block, con el motivo de self-protection
for payload in \
  '{"tool_name":"Write","tool_input":{"file_path":"sentinel/.sdk-version","content":"commit=0\n"}}' \
  '{"tool_name":"Edit","tool_input":{"file_path":"sentinel/.sdk-version","old_string":"dirty=yes","new_string":"dirty=no"}}' ; do
  run_hook "$GUARD_HOOK" "$payload" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    payload: $payload" >&2; exit 1; }
  assert_err_contains "[self-protection]" || { echo "    payload: $payload" >&2; exit 1; }
done

# Escribirla o borrarla desde la shell → block
for cmd in "echo commit=0 > sentinel/.sdk-version" "rm sentinel/.sdk-version" "sed -i '' s/yes/no/ sentinel/.sdk-version"; do
  run_hook "$GUARD_HOOK" "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    cmd: $cmd" >&2; exit 1; }
  assert_err_contains "[self-protection]" || { echo "    cmd: $cmd" >&2; exit 1; }
done

# Leerla desde la shell → pasa
for cmd in "cat sentinel/.sdk-version" "grep commit sentinel/.sdk-version"; do
  run_hook "$GUARD_HOOK" "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done
exit 0
