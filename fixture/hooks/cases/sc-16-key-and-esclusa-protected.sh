#!/usr/bin/env bash
# SC-git-gates-14: el agente no puede crear la llave (sentinel/.override): el break-glass lo
#   concede una persona, nunca el propio agente.
# SC-git-gates-15: el agente no puede desarmar la Esclusa (hooks, su librería, el lector del
#   adaptador) ni saltar sus comprobaciones con las variables de prueba, ni con git commit -n
#   o --no-verify abreviado. Los ficheros del consumidor y la documentación siguen siendo
#   editables.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$DEFAULT_POLICY"

# Deben bloquearse (exit 2)
while IFS= read -r payload; do
  [ -n "$payload" ] || continue
  run_hook "$GUARD_HOOK" "$payload" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
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
  run_hook "$GUARD_HOOK" "$payload" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 0 || { echo "    debería permitirse: $payload" >&2; exit 1; }
done <<'EOF'
{"tool_name":"Write","tool_input":{"file_path":"sentinel/adapters/stack.yaml","content":"tests: npm test"}}
{"tool_name":"Edit","tool_input":{"file_path":"sentinel/githooks/README.md","new_string":"doc"}}
{"tool_name":"Edit","tool_input":{"file_path":"sentinel/adapters/README.md","new_string":"doc"}}
EOF

# Panel de confirmación, V2: -n, la forma corta de --no-verify en git commit (sola o en un grupo
# de opciones), y las abreviaturas que acepta git (--no-veri, --no-verif) también se saltan los
# hooks. En una rama feature, donde el commit se permite; -n no cuenta dentro del mensaje ni
# tras una opción que lleva valor (-mno es el mensaje «no»; -uno, sin los no seguidos). Panel
# corto, A1: también detrás de un mensaje que acaba en ;, & o |
esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$(esc "$1")"; }
trap cleanup_workspace EXIT
mk_workspace
git -C "$WS" checkout -qB feature/x
guard() { RH_CWD="$WS" run_hook "$GUARD_HOOK" "$(bash_payload "$1")" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"; }
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$cmd"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
  assert_err_contains "[no-hook-disabling]" || exit 1
done <<'EOF'
git commit -n -m x
git commit -nm x
git commit -anm x
git commit -a -n -m x
git commit -m x -n
git commit -m 'x y' -n
git commit --amend --no-edit -n
git commit --no-verif -m x
git commit --no-veri -m x
git push --no-verif origin feature/x
git merge --no-verif feature/y
git -C . commit -n -m x
git commit -m 'x;' -n
git commit -m "fix: a;" -n
git commit -m 'R&' -n
git commit -m 'a|' -n
git commit --message 'x;' -n
EOF
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$cmd"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
git commit -m x
git commit -m "usa -n para saltarlo"
git commit -mno
git commit -uno -m x
git commit -m x; ls -n
git log -n 3
git merge -n feature/y
git push -n origin feature/x
git commit --amend --no-edit
git commit -m 'a; -n'
git commit -m 'x;' && ls -n
EOF
exit 0
