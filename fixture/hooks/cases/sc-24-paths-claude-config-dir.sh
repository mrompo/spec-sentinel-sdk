#!/usr/bin/env bash
# SC-sentinel-paths-07: con CLAUDE_CONFIG_DIR en otra carpeta, la configuración de Claude Code
#   de la persona ($CLAUDE_CONFIG_DIR/settings.json) está protegida como la de la ruta por
#   defecto; el resto de esa carpeta, y la misma ruta sin CLAUDE_CONFIG_DIR, no.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$DEFAULT_POLICY"
trap cleanup_workspace EXIT

esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$(esc "$1")"; }

mk_workspace
CFG="$WS/perfil-claude"
mkdir -p "$CFG"; printf '{}\n' >"$CFG/settings.json"

while IFS= read -r payload; do
  [ -n "$payload" ] || continue
  RH_CWD="$WS" run_hook "$GUARD_HOOK" "$payload" CLAUDE_CONFIG_DIR="$CFG" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    debería bloquearse: $payload" >&2; exit 1; }
done <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$CFG/settings.json","content":"{}"}}
{"tool_name":"Edit","tool_input":{"file_path":"perfil-claude/settings.json","new_string":"{}"}}
$(bash_payload "echo '{}' > $CFG/settings.json")
$(bash_payload 'cp /tmp/x.json "$CLAUDE_CONFIG_DIR/settings.json"')
EOF

while IFS= read -r payload; do
  [ -n "$payload" ] || continue
  RH_CWD="$WS" run_hook "$GUARD_HOOK" "$payload" CLAUDE_CONFIG_DIR="$CFG" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 0 || { echo "    debería permitirse: $payload" >&2; exit 1; }
done <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$CFG/notas.md","content":"doc"}}
EOF

# Sin CLAUDE_CONFIG_DIR, esa carpeta es una más del proyecto
RH_CWD="$WS" run_hook "$GUARD_HOOK" "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$CFG/settings.json\",\"content\":\"{}\"}}" \
  -u CLAUDE_CONFIG_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
assert_exit 0 || { echo "    sin CLAUDE_CONFIG_DIR debería permitirse" >&2; exit 1; }
exit 0
