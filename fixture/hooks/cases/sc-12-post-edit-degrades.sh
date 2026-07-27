#!/usr/bin/env bash
# SC-sentinel-guard-12: post-edit formatea vía adaptador; sin entorno, degrada en silencio
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
POST_HOOK="$REPO_ROOT/sentinel/hooks/post-edit.sh"

mk_workspace
echo "contenido" > "$WS/nota.md"
PAYLOAD='{"tool_name":"Edit","tool_input":{"file_path":"nota.md","new_string":"x"}}'

# a) Sin sentinel.yaml → no hace nada, no falla, el fichero queda intacto
RH_CWD="$WS" run_hook "$POST_HOOK" "$PAYLOAD"
assert_exit 0 || { cleanup_workspace; exit 1; }
[ -z "$RH_ERR" ] || { echo "    debía degradar en silencio: $RH_ERR" >&2; cleanup_workspace; exit 1; }
[ "$(cat "$WS/nota.md")" = "contenido" ] || { echo "    el fichero no debía cambiar" >&2; cleanup_workspace; exit 1; }

# b) Con adaptador: el comando format se aplica al fichero editado
cat > "$WS/fmt.sh" <<'EOF'
#!/usr/bin/env bash
echo "#formateado" >> "$1"
EOF
chmod +x "$WS/fmt.sh"
echo "format: bash fmt.sh" > "$WS/sentinel.yaml"
RH_CWD="$WS" run_hook "$POST_HOOK" "$PAYLOAD"
assert_exit 0 || { cleanup_workspace; exit 1; }
grep -q "#formateado" "$WS/nota.md" || { echo "    format no se aplicó" >&2; cleanup_workspace; exit 1; }

# c) Comando format roto → degradación silenciosa
echo "format: comando-inexistente-xyz" > "$WS/sentinel.yaml"
RH_CWD="$WS" run_hook "$POST_HOOK" "$PAYLOAD"
rc=0
assert_exit 0 || rc=1
cleanup_workspace
exit $rc
