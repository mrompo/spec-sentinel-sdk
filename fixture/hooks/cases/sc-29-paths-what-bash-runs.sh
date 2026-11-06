#!/usr/bin/env bash
# SC-sentinel-paths-01, 03: las reglas del comando deciden sobre lo que ejecuta bash, no sobre
#   cómo viene escrito en el JSON (revisión de sentinel-paths, V1 y V2). Un salto de línea o un
#   tabulador escritos como escape del JSON separan igual que escritos tal cual, y el programa
#   se reconoce por su nombre aunque se escriba con su ruta, con una barra delante o entre
#   comillas. Panel de confirmación (V4 = A3, V6, A5): lo que bash ejecuta dentro de "$(…)",
#   de una shell con -c o de eval también cuenta; «<<<» y el «<<» aritmético no abren un
#   heredoc; y lo que busca un lector, entre comillas, no es el programa. Revisiones de la #20
#   (CodeRabbit): lo que sigue a -c, la shell como argumento, los argumentos que leen las
#   reglas, un ")" que bash no lee como cierre de "$(…)" y lo que va detrás de "$(…)", que se
#   lee donde la cierran bash 5, zsh y bash 3.2. Panel corto (P1, V4): el mensaje de git
#   commit o de gh pr en un heredoc con el delimitador entre comillas, que solo lee cat, es
#   texto; con el delimitador sin comillas, bash expande el cuerpo y sus comillas no esconden
#   una sustitución.
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

# Un ")" que bash no lee como cierre no termina la sustitución: el de un comentario llega hasta
# el final de la línea y el del cuerpo de un heredoc no cuenta; tras un case no se sabe dónde
# cierra y se bloquea (segunda y tercera revisión de la #20, CodeRabbit). Cada línea es el
# valor de "command" en el JSON: \n va escrito como escape
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
echo \"$(echo ok # )\n'mv' sentinel/githooks /tmp/x)\"
echo \"$(echo ok # )\nmv sentinel/githooks /tmp/x)\"
echo \"$(echo \"$(echo ok # )\nmv sentinel/githooks /tmp/x)\")\"
echo \"$(cat <<E\n)\nE\nmv sentinel/githooks /tmp/x)\"
echo \"$(cat <<'E'\n)\nE\nmv sentinel/githooks /tmp/x)\"
echo \"$(case x in a) mv sentinel/githooks /tmp/x;; esac)\"
echo \"$(true; case x in (a) true;; b) mv sentinel/githooks /tmp/x;; esac)\"
EOF
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
echo \"$(echo a#b) mv sentinel/githooks /tmp/x\"
echo \"$(echo ${#HOME}) mv sentinel/githooks /tmp/x\"
echo \"$(echo ok # c\n) mv sentinel/githooks /tmp/x\"
echo \"$(echo showcase x) mv sentinel/githooks /tmp/x\"
echo \"$(echo cases) mv sentinel/githooks /tmp/x\"
echo \"$(cat <<< x) mv sentinel/githooks /tmp/x\"
EOF

# Lo que va detrás de la sustitución se lee en su sitio, que es donde la cierran bash 5 y zsh
# y, si no es el mismo, donde la cierra bash 3.2, que cuenta paréntesis sin saltar comentarios,
# heredocs ni ${…}. Si bash 5 no se sabe dónde la cierra (un case, una llave suelta en ${…},
# un salto de línea escapado, una aritmética que no cierra con «))»), se bloquea (tercera
# revisión de la #20, CodeRabbit)
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
echo \"$(case x in a) true;; esac)\" ; '/bin/mv' sentinel/githooks /tmp/x
echo \"$(case x in a) true;; esac)\" ; mv sentinel/githooks /tmp/x
echo \"$(echo case x in a)\" ; mv sentinel/githooks /tmp/x
echo \"$(cat <<E\n)\nE\n)\" ; mv sentinel/githooks /tmp/x
x=\"$(cat <<E\nhola\nE\n)\"; mv sentinel/githooks /tmp/x
echo \"$((1<<2))\" ; mv sentinel/githooks /tmp/x
echo \"$(cat <<E\n)\"; mv sentinel/githooks /tmp/x; echo \"\nE\n)\"
echo \"$(echo ok # )\"; mv sentinel/githooks /tmp/x; echo \"\n)\"
echo \"$(echo $'\\')' ; mv sentinel/githooks /tmp/x)\"
echo \"$(echo ${x/)/} ; mv sentinel/githooks /tmp/x)\"
echo \"$(echo ${x:-)} ; mv sentinel/githooks /tmp/x)\"
echo \"$(echo \"${x:-\")\"}\" ; mv sentinel/githooks /tmp/x)\"
echo \"$(echo ${x:-{} ) } ; mv sentinel/githooks /tmp/x)\"
echo \"$(echo `echo )` ; mv sentinel/githooks /tmp/x)\"
echo \"$(echo \"a`echo \")\"`b\" ; mv sentinel/githooks /tmp/x)\"
echo \"$(( ( echo a # )\nmv sentinel/githooks /tmp/x\n) ) )\"
echo \"$(ca\\\nse x in a) mv sentinel/githooks /tmp/x;; esac)\"
echo \"$((cat <<E\n)\nE\n) ; mv sentinel/githooks /tmp/x ; echo )\"
echo \"$( ((x=1))\necho a # )\nmv sentinel/githooks /tmp/x)\"
echo \"$(echo ${x:-)}\"; mv sentinel/githooks /tmp/x; echo \"\n)\"
echo \"$(cat <<A <<B\nB\nA\n)\nB\nmv sentinel/githooks /tmp/x\n)\"
EOF
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
echo \"$(cat <<'EOF'\nfix(x): no rompe (nada)\n\nIt's fine\nEOF\n)\"
echo \"$(cat <<-E\n\thola )\n\tE\n)\" ; ls sentinel/githooks
echo \"$((1<<2))\" ; ls sentinel/githooks
echo \"$(( (1+2)<<3 ))\" ; ls sentinel/githooks
echo \"$(echo ${x:-a} ${#x} $'a\\'b')\" ; ls sentinel/githooks
x=\"$(cat <<E\nhola\nE\n)\"; echo \"$x\"
echo \"$(echo $((1<<2))\necho a)\" ; echo b
echo \"$(cat <<< x\necho a)\" ; echo b
echo \"$(cat << E\nhola )\nE\n)\" ; echo b
echo \"$(echo `echo )`) ; mv sentinel/githooks /tmp/x ; echo `true`\"
echo \"$(echo \"a`echo \")\"`b\") ; mv sentinel/githooks /tmp/x ; echo `true`\"
echo \"$(echo ${x:-\"}\"}) ; mv sentinel/githooks /tmp/x ; echo `true`\"
echo \"$(echo \"$(echo \")\")\") ; mv sentinel/githooks /tmp/x ; echo `true`\"
EOF
# El bloqueo de un case es el del cierre incierto, aunque detrás no se toque nada protegido
guard "$(bash_payload 'echo "$(case x in a) true;; esac)" ; ls sentinel/githooks')"
assert_exit 2 || { echo "    debería bloquearse: un case dentro de \"\$(…)\"" >&2; exit 1; }
assert_err_contains "no sabe dónde cierra" || exit 1

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

# ── Panel corto, P1 y V4: el cuerpo de un heredoc ─────────────────────────────────────────
# El mensaje de git commit|tag o de gh pr en "$(cat <<'EOF' … EOF)", la forma que usa Claude
# Code, es texto que lee cat: no cuenta aunque nombre un verbo y una carpeta protegida (P1). Lo
# que ejecuta la salida (bash -c, eval, el programa, una tubería a sh, git rebase -x, un alias
# de shell de gh), un programa que no es cat en la línea que abre el heredoc, lo que sigue a la
# línea que lo cierra, un cuerpo que no cierra, un delimitador que no es de la forma de siempre
# y lo que redefine cat (una función, alias, PATH, o lo que ejecuta código en la shell actual:
# eval, source, ., trap, mapfile) siguen contando. En una rama feature, donde el commit se
# permite. Cada línea es el valor de "command" en el JSON
trap cleanup_workspace EXIT
mk_workspace
git -C "$WS" checkout -qB feature/x
mkdir -p "$WS/sentinel/hooks" "$WS/sentinel/githooks" "$WS/.claude"
fguard() { RH_CWD="$WS" run_hook "$GUARD_HOOK" "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"; }
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  fguard "$cmd"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
git commit -m \"$(cat <<'EOF'\nfix(sentinel): mv .git ya se bloquea\nEOF\n)\"
git commit -m \"$(cat <<'EOF'\nfix: chmod -R 000 sentinel/hooks y rm -rf .claude\n\nIt's fine\nEOF\n)\"
git commit -m \"$(cat <<\\EOF\nmv .git /tmp/x\nEOF\n)\"
git commit -m \"$(cat <<-'EOF'\n\tmv .git /tmp/x\n\tEOF\n)\"
git commit -m \"$(cat <<'EOF'\n$(mv sentinel/githooks /tmp/x)\nEOF\n)\"
git commit --amend -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\" && git log -1
git tag -a v1 -m \"$(cat <<'EOF'\nrm -rf .claude\nEOF\n)\"
gh pr create --title x --body \"$(cat <<'EOF'\n`mv .git /tmp/x` ya se bloquea\nEOF\n)\"
git commit -m \"$(cat <<\"EOF\"\nmv .git /tmp/x\nEOF\n)\"
git commit -m \"$(/bin/cat <<'EOF'\nmv .git /tmp/x\nEOF\n)\"
git commit -m \"$(cat <<'EOF'\nfix: mv .git (1)\n2) rm -rf .claude\nEOF\n)\"
gh -R owner/repo pr create --title x --body \"$(cat <<'EOF'\nmv .git /tmp/x\nEOF\n)\"
gh --repo owner/repo pr create --title x --body \"$(cat <<'EOF'\nmv .git /tmp/x\nEOF\n)\"
gh -R; gh pr create --title x --body \"$(cat <<'EOF'\nmv .git /tmp/x\nEOF\n)\"
EOF
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  fguard "$cmd"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
  assert_err_contains "[protect-enforcement-dirs]" || { echo "    por otra regla: $cmd" >&2; exit 1; }
done <<'EOF'
bash -c \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
eval \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
\"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
printf '%s' \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\" | sh
git commit -m \"$(cat <<'EOF' | sh\nmv sentinel/githooks /tmp/x\nEOF\n)\"
git commit -m \"$(bash <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
git commit -m \"$(cat <<'EOF'; mv sentinel/githooks /tmp/x\nx\nEOF\n)\"
git commit -m \"$(cat <<'EOF'\nx\nEOF\nmv sentinel/githooks /tmp/x\n)\"
git commit -m \"$(cat <<'EOF'\nx\nEOF\n)\" ; mv sentinel/githooks /tmp/x
git commit -m \"$(cat <<$'EOF'\nx\nEOF\nmv sentinel/githooks /tmp/x\n$EOF\n)\"
git commit -m \"$(/tmp/x/cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
cat() { bash; }; git commit -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
alias cat=bash; git commit -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
PATH=/tmp/x:$PATH; git commit -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
git commit -m \"$(cat() { bash; }\ncat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
git commit -m \"$( $(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n) )\"
git commit -m \"$( `cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n` )\"
git commit -m x; \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
git rebase -x \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\" main
gh alias set --shell x \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
gh pr list; gh alias set --shell x \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
gh -R pr alias set --shell x \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
eval 'cat() { bash; }'; git commit -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
eval 'alias cat=bash'; git commit -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
builtin eval 'cat() { bash; }'; git commit -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
source /tmp/x/rc; git commit -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
. /tmp/x/rc; git commit -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
trap 'cat() { bash; }' DEBUG; git commit -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
mapfile -C 'cat() { bash; }' -c 1 x < /tmp/x/rc; git commit -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
readarray -C 'cat() { bash; }' -c 1 x < /tmp/x/rc; git commit -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
git commit -m \"$(eval 'cat() { bash; }'\ncat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
git commit -m \"$(source /tmp/x/rc\ncat <<'EOF'\nmv sentinel/githooks /tmp/x\nEOF\n)\"
EOF
# Un cuerpo que no cierra deja la sustitución sin cierre conocido, y eso es lo que la bloquea
while IFS= read -r cmd; do
  fguard "$cmd"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
  assert_err_contains "[too-many-paths]" || { echo "    por otra regla: $cmd" >&2; exit 1; }
done <<'EOF'
git commit -m \"$(cat <<'EOF'\nmv sentinel/githooks /tmp/x\n)\"
EOF

# Con el delimitador sin comillas, bash expande el cuerpo: sus comillas son texto y no esconden
# una sustitución, tampoco tras un apóstrofo (V4). Con el delimitador entre comillas no expande
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  fguard "$cmd"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
cat <<E\n'$(mv sentinel/githooks /tmp/x)'\nE
cat <<E\nit's done $(rm -rf sentinel)\nE
cat <<-E\n\t'$(mv sentinel/githooks /tmp/x)'\n\tE
cat <<E\nit's `mv sentinel/githooks /tmp/x`\nE
cat <<E\n\"$(mv sentinel/githooks /tmp/x)\"\nE
x=$(cat <<E\nit's $(mv sentinel/githooks /tmp/x)\nE\n)
echo \"$(cat <<E\n'$(mv sentinel/githooks /tmp/x)'\nE\n)\"
git commit -m \"$(cat <<EOF\nit's $(mv sentinel/githooks /tmp/x)\nEOF\n)\"
git commit -m \"$(cat <<'A' <<B\nliteral\nA\n$(mv sentinel/githooks /tmp/x)\nB\n)\"
git commit -m \"$(cat <<'A'\nliteral\nA\ncat <<B\n$(mv sentinel/githooks /tmp/x)\nB\n)\"
EOF
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  fguard "$cmd"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
cat <<'E'\n'$(mv sentinel/githooks /tmp/x)'\nE
cat <<E\nit's fine\nE\nls sentinel/githooks
EOF
exit 0
