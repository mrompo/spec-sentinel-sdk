#!/usr/bin/env bash
# SC-sentinel-paths-01: las carpetas protegidas (sentinel, sentinel/hooks, sentinel/githooks,
#   .claude, .git/hooks) no se mueven, copian encima, enlazan, cambian de permisos ni se borran
#   enteras desde la shell; sus subcarpetas que no son enforcement siguen libres.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$DEFAULT_POLICY"

esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$(esc "$1")"; }

# Deben bloquearse (exit 2): las carpetas enteras, se escriban como se escriban
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  run_hook "$GUARD_HOOK" "$(bash_payload "$cmd")" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<EOF
mv sentinel/hooks /tmp/hooks-off
mv sentinel sentinel.off
mv ./sentinel/ /tmp/s
mv "sentinel" x
rm -r sentinel/githooks
rm -rf .claude
rm -rf ./.claude/
git rm -r -q .claude
git mv sentinel/githooks hooks-old
rmdir sentinel/hooks
unlink .git/hooks
ln -s /tmp/evil sentinel/hooks
ln -sfn /tmp/x .claude
chmod -R 000 sentinel
chown -R nobody .claude
cp -R /tmp/evil/. sentinel/githooks
rsync -a --delete /tmp/empty/ sentinel/
cd /tmp && rm -rf $REPO_ROOT/sentinel
EOF

# Deben seguir permitidos (exit 0): subcarpetas libres y lo que no es una carpeta protegida.
# Un rm -r se queda en confirm (destructive), que también sale con 0.
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  run_hook "$GUARD_HOOK" "$(bash_payload "$cmd")" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
mv .claude/skills/a .claude/skills/b
mkdir -p .claude/skills/nueva
rm -r sentinel/.backup
mv docs/sentinel-notas.md docs/notas.md
rm -r fixture/.tmp/ws-1/sentinel
ls sentinel
EOF

# Revisión de la PR 1/3 (CodeRabbit): ni un comando con muchas rutas ni una ruta entre comillas
# con espacios dejan una carpeta protegida sin mirar
trap cleanup_workspace EXIT
mk_workspace
mkdir -p "$WS/sentinel/hooks" "$WS/a b"
relleno=""; for i in $(seq 1 80); do relleno="$relleno docs/f$i.md"; done
for cmd in "rm -rf$relleno sentinel" "mv \"a b/../sentinel\" /tmp/x" "rm -r 'a b/../sentinel/hooks'"; do
  RH_CWD="$WS" run_hook "$GUARD_HOOK" "$(bash_payload "$cmd")" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    debería bloquearse: ${cmd:0:80}…" >&2; exit 1; }
done
# Revisión de la PR #10 (CodeRabbit): una ruta entre comillas con un salto de línea sigue
# siendo una sola palabra (en el JSON del tool call, el salto llega como \n)
mkdir -p "$WS/a
b"
for payload in \
  '{"tool_name":"Bash","tool_input":{"command":"mv \"a\nb/../sentinel\" /tmp/x"}}' \
  '{"tool_name":"Bash","tool_input":{"command":"rm -r '"'"'a\nb/../sentinel/hooks'"'"'"}}'; do
  RH_CWD="$WS" run_hook "$GUARD_HOOK" "$payload" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    debería bloquearse: $payload" >&2; exit 1; }
done
# Un texto de varias líneas entre comillas (p. ej. un mensaje) no es una ruta: sus trozos no
# cuentan como palabras sueltas, aunque uno se llame como una carpeta protegida
RH_CWD="$WS" run_hook "$GUARD_HOOK" '{"tool_name":"Bash","tool_input":{"command":"mv docs/x docs/y && echo \"resumen\nsentinel\""}}' \
  -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
assert_exit 0 || { echo "    un texto de varias líneas debería permitirse" >&2; exit 1; }

# Una ruta con espacios que no es protegida sigue libre
RH_CWD="$WS" run_hook "$GUARD_HOOK" "$(bash_payload "mv \"a b\" c")" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
assert_exit 0 || { echo "    debería permitirse: mv \"a b\" c" >&2; exit 1; }
exit 0
