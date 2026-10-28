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
# Segunda ronda de la #10 (CodeRabbit): los escapes se deshacen como el JSON y la shell. Un
# tabulador, un retorno de carro o un \u00XX no se convierten en otra cosa, y dentro de "…" una
# barra seguida de salto de línea desaparece entera. Nombres nuevos: "a b" y "a⏎b" ya existen y
# también llevarían a sentinel
U='\'u  # la barra de un \u00XX, construida aquí para que el fichero lleve el escape tal cual
mkdir -p "$WS/c"$'\t'"d" "$WS/e"$'\r'"f" "$WS/g"$'\x01'"h"
for payload in \
  '{"tool_name":"Bash","tool_input":{"command":"mv \"sen\\\ntinel\" /tmp/x"}}' \
  '{"tool_name":"Bash","tool_input":{"command":"mv \"c\td/../sentinel\" /tmp/x"}}' \
  '{"tool_name":"Bash","tool_input":{"command":"mv \"e\rf/../sentinel\" /tmp/x"}}' \
  '{"tool_name":"Bash","tool_input":{"command":"mv \"g\u0001h/../sentinel\" /tmp/x"}}' \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"mv ${U}0073entinel /tmp/x\"}}"; do
  RH_CWD="$WS" run_hook "$GUARD_HOOK" "$payload" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    debería bloquearse: $payload" >&2; exit 1; }
done
# Dentro de "…" la barra solo escapa $ ` " \ y el salto de línea: "sentine\l" es la ruta
# sentine\l, no sentinel
RH_CWD="$WS" run_hook "$GUARD_HOOK" '{"tool_name":"Bash","tool_input":{"command":"mv \"sentine\\l\" /tmp/x"}}' \
  -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
assert_exit 0 || { echo "    \"sentine\\l\" no es sentinel y debería permitirse" >&2; exit 1; }

# Un comodín sin comillas se expande contra el disco, como haría la shell, y cada coincidencia
# cuenta. Entre comillas o escapado es literal
mkdir -p "$WS/.claude" "$WS/docs" && : > "$WS/docs/f1.md"
for cmd in "mv sentin* /tmp/x" "rm -rf .cla*" "rm -r sentinel/hoo?s" "mv [s]entinel /tmp/x" \
  "rm -rf *" "mv \"a b\"/../sentin* /tmp/x"; do
  RH_CWD="$WS" run_hook "$GUARD_HOOK" "$(bash_payload "$cmd")" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done
for cmd in "mv \"sentin*\" /tmp/x" "mv \"s*\"* /tmp/x" "mv 'sentin*' /tmp/x" "mv sentin\\* /tmp/x" "mv nada* /tmp/x" \
  "mv docs/f* docs/archivo"; do
  RH_CWD="$WS" run_hook "$GUARD_HOOK" "$(bash_payload "$cmd")" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done

# Tercera ronda de la #10 (CodeRabbit): una palabra que empieza por '-' también es una ruta si
# lleva '/' o existe (tras '--', o porque el comando la toma como tal)
mkdir -p "$WS/-a" && ln -s sentinel "$WS/-s"
for cmd in "mv -- -a/../sentinel /tmp/x" "chmod -R 000 -- -s" "rm -rf -- -s/"; do
  RH_CWD="$WS" run_hook "$GUARD_HOOK" "$(bash_payload "$cmd")" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done
for cmd in "rm -rf docs/x" "mv -f docs/f1.md docs/f2.md" "chmod -R u+w docs"; do
  RH_CWD="$WS" run_hook "$GUARD_HOOK" "$(bash_payload "$cmd")" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done
# Una opción no es una ruta, y se ve con una política que protege justo '-f' (revisión de la #11):
# si existe un fichero '-f', la palabra cuenta y se bloquea; si no existe, -f es la opción y pasa
POL_F="$WS/politica-f.yaml"
printf '%s\n' 'version: 1' 'rules:' '  - id: protege-f' '    tool: Bash' \
  '    command_re: (^|[[:space:]])mv[[:space:]]' '    dir_re: ^-f$' '    mode: block' \
  '    reason: prueba' > "$POL_F"
: > "$WS/-f"
RH_CWD="$WS" run_hook "$GUARD_HOOK" "$(bash_payload "mv -f docs/f1.md docs/f2.md")" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$POL_F"
assert_exit 2 || { echo "    con un fichero '-f', la palabra -f debería contar como ruta" >&2; exit 1; }
rm -f -- "$WS/-f"
RH_CWD="$WS" run_hook "$GUARD_HOOK" "$(bash_payload "mv -f docs/f1.md docs/f2.md")" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$POL_F"
assert_exit 0 || { echo "    sin un fichero '-f', la opción -f no debería contar como ruta" >&2; exit 1; }

# Una ruta con espacios que no es protegida sigue libre
RH_CWD="$WS" run_hook "$GUARD_HOOK" "$(bash_payload "mv \"a b\" c")" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
assert_exit 0 || { echo "    debería permitirse: mv \"a b\" c" >&2; exit 1; }
exit 0
