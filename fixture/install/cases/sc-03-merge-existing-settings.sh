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

# SC-sdk-setup-09: el fragmento sale del .claude/settings.json del SDK, que solo cablea hooks
jq -e 'keys == ["hooks"]' "$REPO_ROOT/.claude/settings.json" >/dev/null \
  || { echo "    el .claude/settings.json del SDK (fuente del fragmento) debe tener solo «hooks»" >&2; exit 1; }
cur_matcher="$(jq -r '.hooks.PreToolUse[] | select(any(.hooks[]; .command | contains("sentinel-guard"))) | .matcher' "$REPO_ROOT/.claude/settings.json")"

# SC-sdk-setup-09: un cableado antiguo (matcher sin Read|Grep|Glob, comando sin comillas, el guard
# compartiendo grupo con un hook propio) se actualiza y lo del consumidor se conserva (P8, A8)
mk_git_workspace
S="$WS/.claude/settings.json"; mkdir -p "$WS/.claude"
cat >"$S" <<'EOF'
{ "hooks": { "PreToolUse": [
  { "matcher": "Bash|Edit|Write|MultiEdit|NotebookEdit",
    "hooks": [ { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/sentinel/hooks/sentinel-guard.sh\"" } ] },
  { "matcher": "Bash",
    "hooks": [ { "type": "command", "command": "bash $CLAUDE_PROJECT_DIR/sentinel/hooks/sentinel-guard.sh" },
               { "type": "command", "command": "echo hook-propio" } ] }
] } }
EOF
run_setup
assert_exit 0 || fail_case "actualizar un cableado antiguo debería terminar con 0: $RH_ERR"
[ "$(settings_count "$S" sentinel-guard)" -eq 1 ] || fail_case "el Centinela debería quedar cableado una sola vez"
[ "$(jq -r '.hooks.PreToolUse[] | select(any(.hooks[]; .command | contains("sentinel-guard"))) | .matcher' "$S")" = "$cur_matcher" ] \
  || fail_case "el matcher del Centinela no se actualizó al del SDK"
[ "$(jq -r '.hooks.PreToolUse[] | select(any(.hooks[]; .command == "echo hook-propio")) | .matcher' "$S")" = "Bash" ] \
  || fail_case "el hook propio debería conservarse con su matcher"
find "$WS/sentinel/.backup" -path '*/.claude/settings.json' -type f | grep -q . || fail_case "actualizar el cableado sin backup"
before="$(ws_snapshot)"; run_setup
assert_exit 0 && [ "$before" = "$(ws_snapshot)" ] || fail_case "tras actualizar, reinstalar debería ser idempotente"
cleanup_git_workspace

# SC-sdk-setup-10: que otra clave nombre un script del SDK (una regla de permisos) no impide cablear (A2-3)
mk_git_workspace
S="$WS/.claude/settings.json"; mkdir -p "$WS/.claude"
printf '{"permissions":{"deny":["Edit(sentinel/hooks/sentinel-guard.sh)"]}}\n' >"$S"
run_setup
assert_exit 0 || fail_case "con una regla de permisos que nombra el guard debería cablear y terminar con 0: $RH_ERR"
[ "$(settings_count "$S" sentinel-guard)" -eq 1 ] || fail_case "el Centinela debería quedar cableado una vez"
[ "$(jq -r '.permissions.deny[0]' "$S")" = "Edit(sentinel/hooks/sentinel-guard.sh)" ] || fail_case "se perdió la regla de permisos"
cleanup_git_workspace

# SC-sdk-setup-09: una forma que no se puede fusionar con seguridad → fragmento y pendiente, no error
mk_git_workspace
S="$WS/.claude/settings.json"; mkdir -p "$WS/.claude"
printf '{"hooks":{"PreToolUse":["x"]}}\n' >"$S"; orig="$(cat "$S")"
run_setup
assert_exit 3 || fail_case "una forma inesperada de settings.json debería terminar con 3, no con error"
[ "$(cat "$S")" = "$orig" ] || fail_case "una forma inesperada de settings.json no se toca"
[ -f "$WS/sentinel/settings.fragment.json" ] || fail_case "debería dejarse el fragmento"
cleanup_git_workspace
