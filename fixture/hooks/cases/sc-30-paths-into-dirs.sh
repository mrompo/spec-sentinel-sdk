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
