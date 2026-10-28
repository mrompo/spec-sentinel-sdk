#!/usr/bin/env bash
# SC-sentinel-paths-03: la configuración de git protegida es la real del repo (también en un
#   repo bare con worktrees, donde no se llama .git), y core.hooksPath no se cambia desde un
#   comando sin nombrarlo: tampoco con los subcomandos sin guiones de git 2.46 ni con las
#   claves en otra caja (git no distingue mayúsculas en sección y clave) o tras un '='
#   (revisión de sentinel-paths, A2 y A3).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$DEFAULT_POLICY"
trap 'cleanup_workspace; [ -n "${B:-}" ] && rm -rf "$B"' EXIT

esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$(esc "$1")"; }

# ── Repo bare + worktree: la configuración vive en .bare/ ────────────────────────────────
mk_workspace
B="$REPO_ROOT/fixture/.tmp/bare-$$-$RANDOM"
mkdir -p "$B"
git clone -q --bare "$WS" "$B/.bare"
printf 'gitdir: ./.bare\n' >"$B/.git"
git -C "$B" worktree add -q -b trabajo wt 2>/dev/null
WT="$B/wt"
[ -f "$WT/README.md" ] || { echo "    no se pudo montar el worktree" >&2; exit 1; }
GD="$(git -C "$WT" rev-parse --absolute-git-dir)"   # .bare/worktrees/wt

while IFS= read -r payload; do
  [ -n "$payload" ] || continue
  RH_CWD="$WT" run_hook "$GUARD_HOOK" "$payload" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    debería bloquearse: $payload" >&2; exit 1; }
done <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"../.bare/config","new_string":"[core]"}}
{"tool_name":"Write","tool_input":{"file_path":"$B/.bare/config","content":"[core]"}}
{"tool_name":"Write","tool_input":{"file_path":"../.bare/hooks/pre-commit","content":"exit 0"}}
{"tool_name":"Write","tool_input":{"file_path":"$GD/config.worktree","content":"[core]"}}
$(bash_payload "printf '[core]\n' >> ../.bare/config")
$(bash_payload "sed -i.bak s/a/b/ $B/.bare/config")
EOF

# Lo que no es la configuración del repo sigue libre
while IFS= read -r payload; do
  [ -n "$payload" ] || continue
  RH_CWD="$WT" run_hook "$GUARD_HOOK" "$payload" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 0 || { echo "    debería permitirse: $payload" >&2; exit 1; }
done <<EOF
{"tool_name":"Write","tool_input":{"file_path":"../.bare/description","content":"repo"}}
{"tool_name":"Write","tool_input":{"file_path":"docs/config","content":"doc"}}
EOF

# ── core.hooksPath sin nombrarlo ─────────────────────────────────────────────────────────
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  run_hook "$GUARD_HOOK" "$(bash_payload "$cmd")" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
git config --remove-section core
git config --local --rename-section core viejo
git config include.path /tmp/evil.cfg
git config --add includeIf.gitdir:~/.path /tmp/x
git -c include.path=/tmp/x commit -m x
git config --edit
git config -e
git config remove-section core
git config --local rename-section core viejo
git config edit
git config core.hookspath /dev/null
git -c CORE.HOOKSPATH=/dev/null commit -m x
git config include.PATH /tmp/x
git config INCLUDE.path /tmp/x
git --config-env=include.path=EVIL commit -m x
git '--config-env=include.path=EVIL' commit -m x
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=include.path GIT_CONFIG_VALUE_0=/tmp/x git commit -m x
EOF

while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  run_hook "$GUARD_HOOK" "$(bash_payload "$cmd")" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 0 || { echo "    debería permitirse: $cmd" >&2; exit 1; }
done <<'EOF'
git config user.name fixture
git config --get core.editor
git config --remove-section alias
git config remove-section alias
git config core.editor edit
git log --oneline -3
EOF
exit 0
