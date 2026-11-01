#!/usr/bin/env bash
# SC-sentinel-paths-01, 03: las reglas del comando deciden sobre lo que ejecuta bash, no sobre
#   cómo viene escrito en el JSON (revisión de sentinel-paths, V1 y V2). Un salto de línea o un
#   tabulador escritos como escape del JSON separan igual que escritos tal cual, y el programa
#   se reconoce por su nombre aunque se escriba con su ruta, con una barra delante o entre
#   comillas. Panel de confirmación (V4 = A3, V6, A5): lo que bash ejecuta dentro de "$(…)",
#   de una shell con -c o de eval también cuenta; «<<<» y el «<<» aritmético no abren un
#   heredoc; y lo que busca un lector, entre comillas, no es el programa.
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

# ── Panel de confirmación, V4 = A3: lo que bash ejecuta dentro de otra cosa ──────────────
# Una sustitución entre comillas dobles ("$(…)", "`…`") se lee como código, también anidada y
# con sus propias comillas; y el argumento de una shell con -c o de eval es un comando más. La
# shell se reconoce también como argumento (sudo -u root, find -exec), y tras -c cuenta lo que
# venga, con más opciones delante del código (revisión de la #20, CodeRabbit)
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$(bash_payload "$cmd")"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
echo "$(mv sentinel/githooks /tmp/x)"
x="$(rm -rf sentinel)"
echo "`mv sentinel/githooks /tmp/x`"
echo "$(echo "a"; mv sentinel/githooks /tmp/x; echo "b")"
echo "a $(echo "$(mv sentinel/githooks /tmp/x)") b"
echo "$( (mv sentinel/githooks /tmp/x) )"
echo "$( (true); mv sentinel/githooks /tmp/x)"
echo "$(echo ')'; mv sentinel/githooks /tmp/x)"
echo "$(echo ")"; mv sentinel/githooks /tmp/x)"
echo "$(echo "$(echo ")")"; mv sentinel/githooks /tmp/x)"
bash -c 'mv sentinel/githooks /tmp/x'
sh -c "chmod -R 000 sentinel/hooks"
eval 'mv sentinel/githooks /tmp/x'
eval "x=1; mv sentinel/githooks /tmp/x"
zsh -c 'rm -rf .claude'
/bin/bash -lc 'mv sentinel/githooks /tmp/x'
sudo bash -c 'mv sentinel/githooks /tmp/x'
bash -c 'bash -c "mv sentinel/githooks /tmp/x"'
bash -c "echo \"\$(mv sentinel/githooks /tmp/x)\""
bash -c -x 'mv sentinel/githooks /tmp/x'
bash -c -- 'mv sentinel/githooks /tmp/x'
bash -c -o pipefail 'mv sentinel/githooks /tmp/x'
sudo -u root bash -c 'mv sentinel/githooks /tmp/x'
env -u X sh -c 'mv sentinel/githooks /tmp/x'
find . -name x -exec sh -c 'mv sentinel/githooks /tmp/x' \;
EOF
# Lo que el código de dentro no ejecuta sobre una carpeta protegida sigue libre
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$(bash_payload "$cmd")"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
echo "$(ls sentinel/githooks)"
bash -c 'ls -la sentinel/githooks'
bash -c -x 'ls -la sentinel/githooks' _ sentinel
sh -c 'echo hola'
eval "echo 'mv sentinel/githooks x'"
echo "$(echo "(") mv sentinel/githooks /tmp/x"
EOF

# ── V6: «<<<» y el «<<» aritmético no abren un heredoc ──────────────────────────────────
# Si lo abrieran, una comilla de dos líneas escondería el comando que la sigue
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
cat <<< x\necho 'a\nb'; mv sentinel/githooks /tmp/x
cat <<<x\necho 'a\nb'; mv sentinel/githooks /tmp/x
echo $((1<<2))\necho 'a\nb'; mv sentinel/githooks /tmp/x
x=$(( 1 << 2 ))\necho 'a\nb'; mv sentinel/githooks /tmp/x
(( a <<= 1 ))\necho 'a\nb'; mv sentinel/githooks /tmp/x
EOF

# ── A5: lo que busca un lector, entre comillas, no es el programa ────────────────────────
# El patrón de grep o de git log/grep y el valor de una asignación no hacen de programa aunque
# se llamen como un verbo: buscar «chmod» en una carpeta protegida es leerla, también con el
# lector detrás de sus prefijos, asignaciones y redirecciones, y git log tras sus opciones
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$(bash_payload "$cmd")"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
grep -rn "chmod" sentinel/hooks
grep -c "cp" .claude
git log --oneline --grep "mv" -- sentinel
grep -rln 'rm' sentinel
grep -rn \chmod sentinel/hooks
X="mv" ls sentinel/githooks
sudo grep -rn "chmod" sentinel/hooks
sudo -E grep -rn "chmod" sentinel/hooks
timeout 5 grep -rn "chmod" sentinel/hooks
X=1 grep -rn "chmod" sentinel/hooks
2>/dev/null grep -rn "chmod" sentinel/hooks
>/dev/null grep -rn "chmod" sentinel/hooks
{ grep -rn "chmod" sentinel/hooks; }
git -C . log --grep "mv" -- sentinel
git --git-dir=.git log --grep "mv" -- sentinel
git -c x.y=z log --grep "mv" -- sentinel
EOF
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$(bash_payload "$cmd")"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
sudo 'mv' sentinel/githooks /tmp/x
X=1 'mv' sentinel/githooks /tmp/x
X= 'mv' sentinel/githooks /tmp/x
nohup "rm" -rf sentinel
git "mv" sentinel/githooks /tmp/x
git -C . 'rm' -r sentinel/githooks
2>/dev/null 'mv' sentinel/githooks /tmp/x
>/dev/null "mv" sentinel/githooks /tmp/x
timeout 5 'mv' sentinel/githooks /tmp/x
sudo -E 'mv' sentinel/githooks /tmp/x
{ 'mv' sentinel/githooks /tmp/x; }
if 'mv' sentinel/githooks /tmp/x; then :; fi
git --git-dir=.git 'mv' sentinel/githooks /tmp/x
git -c x.y=z 'rm' -r sentinel/githooks
bash -o pipefail -c 'mv sentinel/githooks /tmp/x'
bash -e -c 'mv sentinel/githooks /tmp/x'
find . -name x -exec 'rm' -rf sentinel \;
timeout -s KILL 5 'mv' sentinel/githooks /tmp/x
sudo -u root 'mv' sentinel/githooks /tmp/x
EOF

# Los argumentos de cualquier otro programa siguen contando entre comillas: las reglas que los
# leen (un refspec con + o :, la rama a la que se cambia) los ven como sin ellas (revisión de la
# #20, CodeRabbit)
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$(bash_payload "$cmd")"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
git push origin '+main:main'
git push origin "+main:main"
git push origin ':rama'
EOF
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$(bash_payload "$cmd")"
  assert_exit 0 || { echo "    ($cmd)" >&2; exit 1; }
  case "$RH_OUT" in
    *'"permissionDecision":"ask"'*) ;;
    *) echo "    debería pedir confirmación: $cmd" >&2; exit 1 ;;
  esac
done <<'EOF'
git checkout "main"
git switch 'main'
EOF

# Código anidado: hasta 8 niveles se lee entero; con más, no se sabe qué ejecuta y se bloquea
nest() { local c="$2" k; for ((k = 0; k < $1; k++)); do c="echo \"\$($c)\""; done; printf '%s' "$c"; }
guard "$(bash_payload "$(nest 8 true)")"
assert_exit 0 || { echo "    debería permitirse: 8 sustituciones anidadas" >&2; exit 1; }
guard "$(bash_payload "$(nest 9 true)")"
assert_exit 2 || { echo "    debería bloquearse: 9 sustituciones anidadas" >&2; exit 1; }
assert_err_contains "anida código" || exit 1
exit 0
