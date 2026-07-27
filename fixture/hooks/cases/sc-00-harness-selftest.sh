#!/usr/bin/env bash
# Auto-test del harness (no prueba el guard): captura de exit/stderr y workspace git.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

# 1) Un hook dummy que deniega debe capturarse tal cual
dummy="$(mktemp)"
printf '%s\n' '#!/usr/bin/env bash' 'cat >/dev/null' 'echo "motivo de prueba" >&2' 'exit 2' > "$dummy"
run_hook "$dummy" '{"tool_name":"Bash","tool_input":{"command":"echo"}}'
rm -f "$dummy"
assert_exit 2 || exit 1
assert_err_contains "motivo de prueba" || exit 1

# 2) El workspace se crea desde demo-app y es un repo git
mk_workspace
[ -d "$WS/.git" ] || { echo "    workspace sin .git" >&2; cleanup_workspace; exit 1; }
[ -f "$WS/README.md" ] || { echo "    workspace sin contenido de demo-app" >&2; cleanup_workspace; exit 1; }
cleanup_workspace
exit 0
