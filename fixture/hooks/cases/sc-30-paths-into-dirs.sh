#!/usr/bin/env bash
# SC-sentinel-paths-01, 03: copiar o mover a la carpeta que contiene un fichero protegido toca
#   ese fichero, aunque el comando solo nombre la carpeta (revisión de sentinel-paths, A1); las
#   rutas relativas se resuelven desde la carpeta de la sesión, el cwd del tool call (V5); y el
#   tope de rutas solo cuenta las que pueden tocar algo, y la llave lo salva (P5 = A8).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$DEFAULT_POLICY"
trap cleanup_workspace EXIT

esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$(esc "$1")"; }

mk_workspace
mkdir -p "$WS/sentinel/hooks" "$WS/sentinel/githooks/lib" "$WS/sentinel/adapters" "$WS/.husky" \
  "$WS/.claude/skills" "$WS/docs/b" "$WS/home/.config/git"
: >"$WS/docs/a.md"
guard() { # $1=payload [VAR=valor ...]
  local j="$1"; shift
  RH_CWD="$WS" run_hook "$GUARD_HOOK" "$j" -u CLAUDE_PROJECT_DIR HOME="$WS/home" \
    SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY" SENTINEL_OVERRIDES_LOG="$WS/overrides.log" "$@"
}

# ── A1: a la carpeta, con el nombre del origen ───────────────────────────────────────────
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$(bash_payload "$cmd")"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
cp /tmp/e/config .git
cp -f /tmp/e/config .git/
cp -t .git /tmp/e/config
cp --target-directory=.git /tmp/e/config
mv /tmp/e/config .git
cp /tmp/e/stack.sh sentinel/adapters
cp /tmp/e/breakglass.sh sentinel/githooks/lib
cp /tmp/e/.gitconfig ~
cp /tmp/e/config ~/.config/git
mv sentinel/githooks/lib /tmp/x
mv sentinel/adapters /tmp/x
mv .husky /tmp/x
EOF
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$(bash_payload "$cmd")"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
cp docs/a.md docs/b
cp /tmp/e/config docs/b
cp /tmp/e/notas.md .claude/skills
mv /tmp/e/x.md ~
EOF

# ── Revisión de la #16 (CodeRabbit): el programa detrás de un prefijo de ejecución o de
# asignaciones, los orígenes de un comodín, el contenido de una carpeta (rsync con '/' al final,
# 'carpeta/.', -T) y lo que hay dentro de una carpeta copiada ───────────────────────────────
mkdir -p "$WS/docs/e" "$WS/docs/w/worktrees/x" "$WS/docs/cfg/.config/git" "$WS/docs/c" \
  "$WS/docs/r/sentinel/adapters"
: >"$WS/docs/e/config"; : >"$WS/docs/e/policy.yaml"; : >"$WS/docs/w/worktrees/x/config"
: >"$WS/docs/cfg/.config/git/config"; : >"$WS/docs/r/sentinel/adapters/notas.md"
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$(bash_payload "$cmd")"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
command cp /tmp/e/config .git/
sudo cp /tmp/e/config .git/
sudo -u root cp /tmp/e/config .git/
env cp /tmp/e/config .git/
env -i PATH=/bin cp /tmp/e/config .git/
X=1 cp /tmp/e/config .git/
nohup mv /tmp/e/config .git
cp docs/e/* .git/
command cp docs/e/* .git/
cp docs/e/c* .gi?
rsync -a docs/e/ .git/
rsync -rt docs/e/ .git/
rsync -a docs/r/ .
rsync -a docs/e/ sentinel
cp -r docs/e/. .git/
cp -r docs/e/. sentinel
cp -rT docs/e .git
cp -rt .git docs/e/config
cp -t.git /tmp/e/config
cp -r --no-target-directory docs/e .git
cp -r docs/cfg/.config ~
rsync -a docs/w/ .git/
ln -s docs/w/worktrees .git/
EOF
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$(bash_payload "$cmd")"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
sudo cp docs/a.md docs/b
env -i PATH=/bin cp docs/e/config docs/b
cp docs/e/* docs/c
rsync -a docs/e/ docs/c/
cp -r docs/e/. docs/c
cp -r docs/w docs/c
EOF
# Lo que hay dentro de una carpeta copiada tiene un tope, como las rutas: pasado, se bloquea (con
# bastantes entradas de más para que la lista se corte antes de que find termine)
mkdir -p "$WS/docs/t"
(cd "$WS/docs/t" && seq 1 20000 | sed 's/^/f/' | xargs touch)
guard "$(bash_payload "cp -r docs/t/. docs/c")"
assert_exit 2 || { echo "    copiar una carpeta de 20000 ficheros a otra debería bloquearse" >&2; exit 1; }
assert_err_contains "más de 10000 entradas" || exit 1

# ── Revisión de la #17 (CodeRabbit): lo que ya está en el destino como enlace escribe donde
# apunta, y de lo que el Centinela no puede leer en el origen no se sabe qué deja en el destino
mkdir -p "$WS/docs/l" "$WS/docs/s/g"
: >"$WS/docs/s/g/config"
ln -s ../../sentinel/policy.yaml "$WS/docs/l/config"
ln -s ../../.git "$WS/docs/l/g"
for cmd in "cp -r docs/e/. docs/l" "cp -r docs/s/. docs/l"; do
  guard "$(bash_payload "$cmd")"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done
if [ "$(id -u)" != 0 ]; then
  mkdir -p "$WS/docs/u/sub"; : >"$WS/docs/u/sub/x"
  chmod 000 "$WS/docs/u/sub"; guard "$(bash_payload "cp -r docs/u docs/c")"; chmod 755 "$WS/docs/u/sub"
  assert_exit 2 || { echo "    copiar una carpeta que no se puede leer entera debería bloquearse" >&2; exit 1; }
  assert_err_contains "no puede leer entera" || exit 1
  printf 'copia de prueba\npara: Bash:cp -r docs/u docs/c\n' >"$WS/sentinel/.override"
  chmod 000 "$WS/docs/u/sub"; guard "$(bash_payload "cp -r docs/u docs/c")"; chmod 755 "$WS/docs/u/sub"
  assert_exit 0 || { echo "    con su llave, la carpeta que no se puede leer entera debería permitirse" >&2; exit 1; }
fi

# ── V5: la carpeta de la sesión es el cwd del tool call ──────────────────────────────────
guard "{\"cwd\":\"$WS/sentinel\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"mv hooks /tmp/x\"}}"
assert_exit 2 || { echo "    con el cwd en sentinel, mv hooks debería bloquearse" >&2; exit 1; }
guard "{\"cwd\":\"$WS/sentinel\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"policy.yaml\",\"content\":\"x\"}}"
assert_exit 2 || { echo "    con el cwd en sentinel, escribir policy.yaml debería bloquearse" >&2; exit 1; }
guard "{\"cwd\":\"$WS/docs\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"mv hooks /tmp/x\"}}"
assert_exit 0 || { echo "    con el cwd en docs, mv hooks debería permitirse" >&2; exit 1; }

# ── P5 = A8: el tope de rutas ────────────────────────────────────────────────────────────
# Un heredoc con texto que lleva '/' (divisiones, URLs) no nombra rutas: sus carpetas no existen
hd="cat > docs/x.py <<'EOF'\\n"
for i in $(seq 1 200); do hd="${hd}y = a/b + c/d  # https://example.com/p/$i\\n"; done
hd="${hd}EOF"
guard "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$hd\"}}"
assert_exit 0 || { echo "    un heredoc con 200 líneas de texto con '/' debería permitirse" >&2; exit 1; }
# Un git add de 200 ficheros que existen
mkdir -p "$WS/docs/n"
lista=""; for i in $(seq 1 200); do : >"$WS/docs/n/f$i.md"; lista="$lista docs/n/f$i.md"; done
guard "$(bash_payload "git add$lista")"
assert_exit 0 || { echo "    un git add de 200 ficheros debería permitirse" >&2; exit 1; }
# Más rutas de las que el Centinela comprueba: se deniega, y la llave de esa acción lo salva
mkdir -p "$WS/docs/m"
for i in $(seq 1 600); do : >"$WS/docs/m/f$i.md"; done
guard "$(bash_payload "rm -f docs/m/*")"
assert_exit 2 || { echo "    un comodín de 600 rutas debería denegarse" >&2; exit 1; }
assert_err_contains "para: Bash:rm -f docs/m/*" || exit 1
printf 'limpieza de prueba\npara: Bash:rm -f docs/m/*\n' >"$WS/sentinel/.override"
guard "$(bash_payload "rm -f docs/m/*")"
assert_exit 0 || { echo "    con su llave, el comodín de 600 rutas debería permitirse" >&2; exit 1; }
exit 0
