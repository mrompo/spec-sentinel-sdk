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

# Lo que bash no lee como palabras no esconde las líneas siguientes (revisión de la #15,
# CodeRabbit): una comilla en un comentario, una comilla escapada dentro de $'…' o una comilla
# suelta en el cuerpo de un heredoc. El cuerpo se lee línea a línea (sin comillas que pasen de
# una a otra), así que un '<<' que no abre un heredoc, como el de una expresión aritmética,
# tampoco esconde nada
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
cat x # it's\nrm sentinel/policy.yaml
cat x # it's\nmv sentinel/githooks /tmp/x
cat $'a\\'b'\nrm sentinel/policy.yaml
echo $'a\\'b'\nmv sentinel/githooks /tmp/x
cat <<'FIN'\nit's\nFIN\nmv sentinel/githooks /tmp/x
cat <<-FIN\n\tit's\n\tFIN\nmv sentinel/githooks /tmp/x
cat <<A <<'B'\nit's\nA\nit's\nB\nmv sentinel/githooks /tmp/x
X=#; mv sentinel/githooks /tmp/x
(( a << 2 ))\nmv sentinel/githooks /tmp/x
EOF
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
grep -n '#' sentinel/policy.yaml
cat sentinel/policy.yaml # it's fine
echo a#b; cat sentinel/policy.yaml
echo ${#HOME}; cat sentinel/policy.yaml
EOF

# Tras la línea que cierra el heredoc, el comando vuelve a leerse como siempre: un texto de
# varias líneas entre comillas es una sola palabra, aunque una línea se llame como una carpeta
# protegida (con <<-, la línea que cierra puede llevar tabuladores delante)
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
cat <<'FIN'\nx\nFIN\nmv docs/x docs/y && echo \"a\nsentinel\"
cat <<-FIN\n\tx\n\tFIN\nmv docs/x docs/y && echo \"a\nsentinel\"
cat <<A <<'B'\nx\nA\ny\nB\nmv docs/x docs/y && echo \"a\nsentinel\"
EOF

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
