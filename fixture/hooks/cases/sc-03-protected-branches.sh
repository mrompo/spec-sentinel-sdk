#!/usr/bin/env bash
# SC-sentinel-guard-03: git commit en rama protegida → block; en rama feature → pasa. También
#   detrás de git -C <carpeta>, git -c <clave>=<valor>, env, command o una asignación (panel de
#   confirmación de sentinel-paths, A4 = V9)
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$(esc "$1")"; }
guard() { RH_CWD="$WS" run_hook "$GUARD_HOOK" "$(bash_payload "$1")" SENTINEL_POLICY_DEFAULT="$DEFAULT_POLICY" SENTINEL_POLICY="$CONSUMER_POLICY"; }
trap cleanup_workspace EXIT
mk_workspace

git -C "$WS" checkout -qB main
guard 'git commit -m "x"'
assert_exit 2 || exit 1
assert_err_contains "Rama protegida" || exit 1
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$cmd"
  assert_exit 2 || { echo "    en main debería bloquearse: $cmd" >&2; exit 1; }
  assert_err_contains "Rama protegida" || exit 1
done <<'EOF'
git -C . commit -m x
git -c user.name=x commit -m x
/usr/bin/git -c user.name=x commit -m x
git -c 'user.name=a b' commit -m x
env git commit -m x
command git commit -m x
X=1 git commit -m x
GIT_AUTHOR_NAME=x git commit -m x
2>/dev/null git commit -m x
git --git-dir .git commit -m x
git --work-tree . commit -m x
nice -n 5 git commit -m x
timeout 60 git commit -m x
git -C . -c user.name=x merge feature/algo
EOF
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$cmd"
  assert_exit 0 || { echo "    en main debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
git -C . status
git -c user.name=x log -1
echo git commit -m x
git --git-dir .git log -1
EOF

git -C "$WS" checkout -qB feature/algo
for cmd in 'git commit -m "x"' "git -C . commit -m x" "env git commit -m x" "X=1 git commit -m x"; do
  guard "$cmd"
  assert_exit 0 || { echo "    en una rama feature debería permitirse: $cmd" >&2; exit 1; }
done
exit 0
