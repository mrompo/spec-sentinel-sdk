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
add_cmd="$(printf '%s\n' "$RH_ERR" | sed -n 's/.*\(git add sentinel [^"]*\)$/\1/p' | head -1)"
[ -n "$add_cmd" ] || fail_case "la salida debería proponer el git add"

( cd "$WS" && HOME="$WS.home" XDG_CONFIG_HOME="$WS.home/.config" eval "$add_cmd" ) \
  || fail_case "el git add que propone setup falló: $add_cmd"
staged="$(git_in_ws diff --cached --name-only)"
printf '%s\n' "$staged" | grep -qxF ".claude/settings.json" || fail_case "el git add debería incluir .claude/settings.json"
printf '%s\n' "$staged" | grep -qxF ".claude/settings.local.json" && fail_case "el git add incluye .claude/settings.local.json"

# Reinstalar no repite la línea
run_setup
[ "$(grep -cxF ".claude/settings.local.json" "$WS/.gitignore")" -eq 1 ] || fail_case "reinstalar repitió la línea del .gitignore"

# Se comprueba con git, no buscando la línea: una negación posterior deja pendiente (V5-5)
cp "$WS/.gitignore" "$WS.gi"; printf '!.claude/settings.local.json\n' >>"$WS/.gitignore"
run_setup
assert_exit 3 || fail_case "con una negación posterior de settings.local.json debería terminar con 3: $RH_ERR"
assert_out_contains ".claude/settings.local.json" || fail_case "el pendiente debería nombrar .claude/settings.local.json"
mv "$WS.gi" "$WS/.gitignore"

# Ya versionado: el .gitignore no lo saca del índice, así que queda pendiente con el comando
# que lo hace (P5-5 = A5-7)
git_in_ws add -f .claude/settings.local.json
run_setup
assert_exit 3 || fail_case "con settings.local.json ya versionado debería terminar con 3: $RH_ERR"
assert_out_contains "git rm --cached .claude/settings.local.json" || fail_case "el pendiente debería dar el comando que lo saca del índice"
git_in_ws rm -q --cached .claude/settings.local.json
run_setup
assert_exit 0 || fail_case "con settings.local.json fuera del índice debería terminar con 0: $RH_ERR"

# Los backups también se comprueban con git (A6-6)
cp "$WS/.gitignore" "$WS.gi"; printf '!sentinel/.backup/\n' >>"$WS/.gitignore"
run_setup
assert_exit 3 || fail_case "con una negación posterior de sentinel/.backup/ debería terminar con 3: $RH_ERR"
assert_out_contains "sentinel/.backup/" || fail_case "el pendiente debería nombrar sentinel/.backup/"
mv "$WS.gi" "$WS/.gitignore"

# Una llave que ya está al instalar deja pasar la primera acción que el Centinela bloquee: se
# avisa, y la decide la persona (A6-3)
printf 'una llave de antes\n' >"$WS/sentinel/.override"
run_setup
assert_exit 3 || fail_case "con una llave sentinel/.override ya presente debería terminar con 3: $RH_ERR"
assert_out_contains "sentinel/.override" || fail_case "el pendiente debería nombrar la llave"
[ -f "$WS/sentinel/.override" ] || fail_case "setup no debe gastar ni borrar la llave"
rm -f "$WS/sentinel/.override"
run_setup
assert_exit 0 || fail_case "sin la llave debería terminar con 0: $RH_ERR"

rm -rf "$WS.home"
cleanup_git_workspace
