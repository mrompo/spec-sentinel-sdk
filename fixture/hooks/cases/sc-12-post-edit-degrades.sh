#!/usr/bin/env bash
# SC-sentinel-guard-12: post-edit formatea vía adaptador; sin entorno, degrada en silencio.
# SC-git-gates-07 (slice 3b): el adaptador se lee de sentinel/adapters/stack.yaml, el mismo que
# la Esclusa; el antiguo sentinel.yaml de la raíz ya no se lee (el nombre era ambiguo).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
POST_HOOK="$REPO_ROOT/sentinel/hooks/post-edit.sh"

mk_workspace
echo "contenido" > "$WS/nota.md"
PAYLOAD='{"tool_name":"Edit","tool_input":{"file_path":"nota.md","new_string":"x"}}'

# a) Sin adaptador → no hace nada, no falla, el fichero queda intacto
RH_CWD="$WS" run_hook "$POST_HOOK" "$PAYLOAD"
assert_exit 0 || { cleanup_workspace; exit 1; }
[ -z "$RH_ERR" ] || { echo "    debía degradar en silencio: $RH_ERR" >&2; cleanup_workspace; exit 1; }
[ "$(cat "$WS/nota.md")" = "contenido" ] || { echo "    el fichero no debía cambiar" >&2; cleanup_workspace; exit 1; }

cat > "$WS/fmt.sh" <<'EOF'
#!/usr/bin/env bash
echo "#formateado" >> "$1"
EOF
chmod +x "$WS/fmt.sh"

# b) El antiguo sentinel.yaml de la raíz ya NO se lee
echo "format: bash fmt.sh" > "$WS/sentinel.yaml"
RH_CWD="$WS" run_hook "$POST_HOOK" "$PAYLOAD"
assert_exit 0 || { cleanup_workspace; exit 1; }
! grep -q "#formateado" "$WS/nota.md" || { echo "    leyó el sentinel.yaml antiguo de la raíz" >&2; cleanup_workspace; exit 1; }
rm -f "$WS/sentinel.yaml"

# c) Con el adaptador en su sitio: el comando format se aplica al fichero editado
mkdir -p "$WS/sentinel/adapters"
echo "format: bash fmt.sh" > "$WS/sentinel/adapters/stack.yaml"
RH_CWD="$WS" run_hook "$POST_HOOK" "$PAYLOAD"
assert_exit 0 || { cleanup_workspace; exit 1; }
grep -q "#formateado" "$WS/nota.md" || { echo "    format no se aplicó desde sentinel/adapters/stack.yaml" >&2; cleanup_workspace; exit 1; }

# d) Comando format roto → degradación silenciosa
echo "format: comando-inexistente-xyz" > "$WS/sentinel/adapters/stack.yaml"
RH_CWD="$WS" run_hook "$POST_HOOK" "$PAYLOAD"
rc=0
assert_exit 0 || rc=1
cleanup_workspace
exit $rc
