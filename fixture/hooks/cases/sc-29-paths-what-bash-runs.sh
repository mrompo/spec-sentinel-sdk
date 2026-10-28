#!/usr/bin/env bash
# SC-sentinel-paths-01, 03: las reglas del comando deciden sobre lo que ejecuta bash, no sobre
#   cómo viene escrito en el JSON (revisión de sentinel-paths, V1 y V2). Un salto de línea o un
#   tabulador escritos como escape del JSON separan igual que escritos tal cual, y el programa
#   se reconoce por su nombre aunque se escriba con su ruta, con una barra delante o entre
#   comillas.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$DEFAULT_POLICY"

esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$(esc "$1")"; }
guard() { run_hook "$GUARD_HOOK" "$1" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"; }

# ── V1: el comando tal como lo ve bash, con los escapes del JSON deshechos ───────────────
# Cada línea es el valor de "command" en el JSON: \n y \t van escritos como escape
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
echo x\nmv sentinel/githooks /tmp/x
echo x\nrm -rf sentinel
mv\tsentinel/githooks\t/tmp/x
true\ngit config --remove-section core
git\tconfig\t--remove-section\tcore
true\ngit config include.path /tmp/x
git config\tinclude.path /tmp/x
true\nSENTINEL_OVERRIDE=x git commit -m x
EOF

# Un '=' escrito como escape del JSON también es un '=' para bash (la barra se construye aquí
# para que el fichero lleve el escape tal cual)
U='\'u
guard "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"HUSKY${U}003d0 git commit -m x\"}}"
assert_exit 2 || { echo "    debería bloquearse: HUSKY=0 con el '=' escrito como escape" >&2; exit 1; }

# ── V2: el programa por su nombre ────────────────────────────────────────────────────────
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$(bash_payload "$cmd")"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
/bin/mv sentinel/githooks /tmp/x
\mv sentinel/githooks /tmp/x
'mv' sentinel/githooks /tmp/x
"mv" sentinel/githooks /tmp/x
m"v" sentinel/githooks /tmp/x
/bin/rm -rf .claude
echo x; /bin/chmod -R 000 sentinel/hooks
/usr/bin/env mv sentinel/githooks /tmp/x
EOF

# Lo que no ejecuta nada sobre una carpeta protegida sigue libre
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
echo x\nls sentinel/githooks
/bin/ls -la sentinel/githooks
echo 'mv sentinel/githooks x'
git log --oneline -3\ngit status
EOF
exit 0
