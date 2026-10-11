#!/usr/bin/env bash
# SC-sdk-setup-03: con un .claude/settings.json previo y jq disponible, los hooks y claves del
# consumidor se conservan, se crea un backup del original y se añaden los del SDK.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1
command -v jq >/dev/null 2>&1 || { echo "    este caso necesita jq (sin jq no se puede verificar la fusión)" >&2; exit 1; }

mk_git_workspace
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

S="$WS/.claude/settings.json"; mkdir -p "$WS/.claude"
cat >"$S" <<'EOF'
{
  "permissions": { "deny": ["Bash(rm:*)"] },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo hook-propio" } ] }
    ]
  }
}
EOF
orig="$(cat "$S")"

run_setup
assert_exit 0 || fail_case "la fusión con jq debería terminar con 0"

[ "$(jq -r '.permissions.deny[0]' "$S")" = "Bash(rm:*)" ] || fail_case "se perdieron los permisos del consumidor"
[ "$(settings_count "$S" hook-propio)" -eq 1 ] || fail_case "se perdió el hook propio del consumidor"
[ "$(settings_count "$S" sentinel-guard)" -eq 1 ] || fail_case "no se añadió el Centinela"
[ "$(settings_count "$S" post-edit)" -eq 1 ] || fail_case "no se añadió post-edit"
[ "$(settings_count "$S" session-start)" -eq 1 ] || fail_case "no se añadió session-start"

backups="$(find "$WS/sentinel/.backup" -path '*/.claude/settings.json' -type f 2>/dev/null)"
[ "$(printf '%s' "$backups" | grep -c .)" -eq 1 ] || fail_case "debería haber exactamente un backup de settings.json"
[ "$(cat "$backups")" = "$orig" ] || fail_case "el backup no es el original"
grep -qxF "sentinel/.backup/" "$WS/.gitignore" || fail_case ".gitignore no excluye los backups"
assert_out_contains "backup" || fail_case "la salida no menciona el backup"
cleanup_git_workspace
