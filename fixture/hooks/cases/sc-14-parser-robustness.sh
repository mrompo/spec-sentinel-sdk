#!/usr/bin/env bash
# SC-sentinel-guard-14 (hallazgos de parser del panel): formatos que antes rompían en silencio.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
mk_workspace
PAYLOAD='{"tool_name":"Edit","tool_input":{"file_path":"cualquiera.txt","new_string":"x"}}'
rc=0

# a) Comentario indentado que menciona una clave NO debe alterar la regla
cat > "$WS/p1.yaml" <<'EOF'
version: 1
rules:
  - id: demo
    tool: Edit
    # mode: block   ← comentario, no debe ganar
    mode: warn
    reason: aviso de prueba
EOF
run_hook "$GUARD_HOOK" "$PAYLOAD" SENTINEL_POLICY="$WS/p1.yaml"
assert_exit 0 || rc=1
assert_err_contains "warn:demo" || rc=1

# b) Un reason: que menciona otra clave no debe secuestrar el matching
cat > "$WS/p2.yaml" <<'EOF'
version: 1
rules:
  - id: demo2
    tool: Edit
    mode: block
    reason: usa el tool: correcto o revisa el mode: elegido
EOF
run_hook "$GUARD_HOOK" "$PAYLOAD" SENTINEL_POLICY="$WS/p2.yaml"
assert_exit 2 || rc=1

# c) Política con 'rules:' pero sin reglas → fail-closed (no "todo pasa")
printf 'version: 1\nrules:\n' > "$WS/p3.yaml"
run_hook "$GUARD_HOOK" "$PAYLOAD" SENTINEL_POLICY="$WS/p3.yaml"
assert_exit 2 || rc=1
assert_err_contains "sin reglas" || rc=1

# d) Regla sin mode: → error explícito, no regla ignorada
printf 'version: 1\nrules:\n  - id: rota\n    tool: Edit\n' > "$WS/p4.yaml"
run_hook "$GUARD_HOOK" "$PAYLOAD" SENTINEL_POLICY="$WS/p4.yaml"
assert_exit 2 || rc=1
assert_err_contains "sin 'mode:'" || rc=1

# e) Regex inválida → error de política, no fail-open
printf 'version: 1\nrules:\n  - id: mala\n    tool: Edit\n    path_re: a(\n    mode: block\n    reason: x\n' > "$WS/p5.yaml"
run_hook "$GUARD_HOOK" "$PAYLOAD" SENTINEL_POLICY="$WS/p5.yaml"
assert_exit 2 || rc=1
assert_err_contains "regex inválida" || rc=1

cleanup_workspace
exit $rc
