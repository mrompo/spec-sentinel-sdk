#!/usr/bin/env bash
# SC-sdk-setup-15: lo personal no se versiona. Claude Code excluye .claude/settings.local.json en
# el ignore global de git, que git no lee si hay un core.excludesFile propio. El .gitignore del
# repo lo excluye, y el «git add sentinel .claude .gitignore» que propone setup no lo incluye (A4-6).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; rm -rf "$WS.home"; cleanup_git_workspace; exit 1; }
mkdir -p "$WS/.claude" "$WS.home/.config/git"
printf '{"permissions":{"allow":["Bash(*)"]}}\n' >"$WS/.claude/settings.local.json"
# El ignore global donde lo pone Claude Code, y un core.excludesFile propio que lo deja sin leer
printf '.claude/settings.local.json\n' >"$WS.home/.config/git/ignore"
printf '.DS_Store\n' >"$WS.home/.gitignore_global"
git_in_ws config core.excludesFile "$WS.home/.gitignore_global"

run_setup
assert_exit 0 || fail_case "la instalación debería terminar con 0: $RH_ERR"
grep -qxF ".claude/settings.local.json" "$WS/.gitignore" || fail_case ".gitignore no excluye .claude/settings.local.json"
assert_out_contains "git add sentinel .claude .gitignore" || fail_case "la salida debería proponer el git add"

( cd "$WS" && HOME="$WS.home" XDG_CONFIG_HOME="$WS.home/.config" git add sentinel .claude .gitignore ) \
  || fail_case "el git add que propone setup falló"
staged="$(git_in_ws diff --cached --name-only)"
printf '%s\n' "$staged" | grep -qxF ".claude/settings.json" || fail_case "el git add debería incluir .claude/settings.json"
printf '%s\n' "$staged" | grep -qxF ".claude/settings.local.json" && fail_case "el git add incluye .claude/settings.local.json"

# Reinstalar no repite la línea
run_setup
[ "$(grep -cxF ".claude/settings.local.json" "$WS/.gitignore")" -eq 1 ] || fail_case "reinstalar repitió la línea del .gitignore"

rm -rf "$WS.home"
cleanup_git_workspace
