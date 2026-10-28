#!/usr/bin/env bash
# SC-sentinel-paths-02: a través de un enlace (del propio fichero o de una carpeta de su ruta)
#   las herramientas de edición no tocan un fichero protegido; un enlace hacia algo libre sigue
#   libre. Un '..' detrás de un enlace sube desde donde apunta el enlace, como lo resuelve el
#   sistema (revisión de sentinel-paths, A7).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$DEFAULT_POLICY"
trap cleanup_workspace EXIT

mk_workspace
mkdir -p "$WS/sentinel/hooks" "$WS/.claude" "$WS/docs" "$WS/sub"
: >"$WS/sentinel/policy.yaml"; : >"$WS/.claude/settings.json"
ln -s sentinel "$WS/s"                       # carpeta protegida
ln -s .claude "$WS/c"
ln -s .git "$WS/g"
ln -s sentinel/policy.yaml "$WS/p.yaml"      # el propio fichero
ln -s ../sentinel "$WS/sub/up"               # enlace relativo desde otra carpeta
ln -s docs "$WS/d"                           # enlace libre
ln -s README.md "$WS/leeme.md"
ln -s sentinel/hooks "$WS/h"                 # h/.. es sentinel, no la raíz

while IFS= read -r payload; do
  [ -n "$payload" ] || continue
  RH_CWD="$WS" run_hook "$GUARD_HOOK" "$payload" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    debería bloquearse: $payload" >&2; exit 1; }
done <<EOF
{"tool_name":"Write","tool_input":{"file_path":"s/policy.yaml","content":"version: 1"}}
{"tool_name":"Edit","tool_input":{"file_path":"c/settings.json","new_string":"{}"}}
{"tool_name":"Write","tool_input":{"file_path":"p.yaml","content":"version: 1"}}
{"tool_name":"Edit","tool_input":{"file_path":"g/config","new_string":"[core]"}}
{"tool_name":"Write","tool_input":{"file_path":"s/hooks/nuevo.sh","content":"exit 0"}}
{"tool_name":"MultiEdit","tool_input":{"file_path":"sub/up/policy.yaml","edits":[]}}
{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"c/settings.json","new_source":"x"}}
{"tool_name":"Write","tool_input":{"file_path":"$WS/s/policy.yaml","content":"version: 1"}}
{"tool_name":"Write","tool_input":{"file_path":"h/../policy.yaml","content":"version: 1"}}
{"tool_name":"Edit","tool_input":{"file_path":"$WS/h/../policy.yaml","new_string":"x"}}
EOF

while IFS= read -r payload; do
  [ -n "$payload" ] || continue
  RH_CWD="$WS" run_hook "$GUARD_HOOK" "$payload" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 0 || { echo "    debería permitirse: $payload" >&2; exit 1; }
done <<'EOF'
{"tool_name":"Write","tool_input":{"file_path":"d/nuevo.md","content":"doc"}}
{"tool_name":"Edit","tool_input":{"file_path":"leeme.md","new_string":"doc"}}
{"tool_name":"Write","tool_input":{"file_path":"sub/libre.md","content":"doc"}}
EOF
exit 0
