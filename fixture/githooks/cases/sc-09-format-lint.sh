#!/usr/bin/env bash
# SC-git-gates-09: format-check o lint en rojo → commit rechazado mostrando la salida del
# comando; los ficheros que no están en staging no se le pasan al comando.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
gl="$(gl_ok)"

# Comprobador falso: falla si algún fichero recibido contiene «MAL», y dice cuál
chk="$WS/.bin/check"; mkdir -p "$WS/.bin"
cat >"$chk" <<'EOF'
#!/usr/bin/env bash
rc=0
for f in "$@"; do grep -q MAL "$f" && { echo "formato incorrecto en $f"; rc=1; }; done
exit $rc
EOF
chmod +x "$chk"
mkdir -p "$WS/sentinel/adapters"

for key in format-check lint; do
  printf '%s: %s\n' "$key" "$chk" >"$WS/sentinel/adapters/stack.yaml"
  git_in_ws reset -q; git_in_ws checkout -q -- . 2>/dev/null || true
  rm -f "$WS/bien.txt" "$WS/mal.txt"

  # Un fichero mal formateado SIN stagear no se evalúa
  printf 'bien %s\n' "$key" >"$WS/bien.txt"; printf 'MAL\n' >"$WS/mal.txt"
  git_in_ws add bien.txt
  _capture env "$gl" git commit -q -m "feat: bien"
  assert_exit 0 || fail_case "$key: evaluó un fichero fuera de staging"

  # Stageado → rechazo con la salida del comando
  git_in_ws add mal.txt
  _capture env "$gl" git commit -q -m "feat: mal"
  assert_exit 1 || fail_case "$key: aceptó un fichero en rojo"
  assert_err_contains "formato incorrecto en mal.txt" || fail_case "$key: no muestra la salida del comando"
  git_in_ws rm -q --cached mal.txt
done
cleanup_git_workspace
