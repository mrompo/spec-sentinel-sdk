#!/usr/bin/env bash
# SC-sdk-setup-14: cableado no es lo mismo que efectivo. Con disableAllHooks distinto de false,
# o con un env que fija variables SENTINEL_*, en el proyecto, en el local o en la configuración de
# usuario de Claude Code, setup termina con 3 nombrando el fichero y la clave. Un fichero que no
# se puede leer como JSON válido queda pendiente, nunca se da por bueno (A3-1, A4-2 = V4-2,
# A4-3 = P4-4, A4-5, V4-1, V4-3).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

fail_case() { echo "    $1" >&2; rm -rf "$WS.cc" "$WS.home"; cleanup_git_workspace; exit 1; }

# case_in <fichero relativo al workspace o «user»> <contenido> <exit esperado> <texto esperado> <qué>
case_in() {
  local where="$1" body="$2" want="$3" says="$4" what="$5" f
  mk_git_workspace
  mkdir -p "$WS/.claude" "$WS.cc"
  case "$where" in user) f="$WS.cc/settings.json" ;; *) f="$WS/$where" ;; esac
  printf '%s\n' "$body" >"$f"
  run_setup CLAUDE_CONFIG_DIR="$WS.cc"
  assert_exit "$want" || fail_case "con $what en $where debería terminar con $want: $RH_ERR"
  [ -z "$says" ] || assert_out_contains "$says" || fail_case "con $what en $where, la salida debería nombrar «$says»"
  rm -rf "$WS.cc"; cleanup_git_workspace
}

for where in .claude/settings.json .claude/settings.local.json user; do
  case_in "$where" '{"disableAllHooks": true}'    3 disableAllHooks "disableAllHooks: true"
  case_in "$where" '{"disableAllHooks": 1}'       3 disableAllHooks "disableAllHooks: 1"
  case_in "$where" '{"disableAllHooks": "false"}' 3 disableAllHooks "disableAllHooks: \"false\""
  case_in "$where" '{"disableAllHooks": false}'   0 ""              "disableAllHooks: false"
  case_in "$where" '{"env": {"SENTINEL_POLICY": "/dev/null"}}' 3 SENTINEL_POLICY "un env con SENTINEL_POLICY"
  case_in "$where" '{"env": {"NODE_ENV": "test"}}' 0 ""             "un env sin SENTINEL_*"
done
# De una clave repetida vale la última, y un escape en la clave es la misma clave (A4-2, A4-5)
case_in .claude/settings.local.json '{"disableAllHooks": false, "disableAllHooks": true}' 3 disableAllHooks "disableAllHooks repetida, la última true"
case_in .claude/settings.local.json '{"disableAllHooks": true, "disableAllHooks": false}' 0 "" "disableAllHooks repetida, la última false"
case_in .claude/settings.local.json '{"disableAllHooks": true}' 3 disableAllHooks "disableAllHooks escrita con un escape"
case_in .claude/settings.local.json '{"env": {"SENTINEL_OVERRIDE": "x"}}' 3 SENTINEL_OVERRIDE "SENTINEL_OVERRIDE escrita con un escape"
# Un fichero que no se puede leer: no se puede comprobar, así que queda pendiente
case_in .claude/settings.local.json '{"disableAllHooks": true,}' 3 "no se puede comprobar" "un settings.local.json que no es JSON válido"
case_in user '{"disableAllHooks": NaN}' 3 "no se puede comprobar" "una configuración de usuario que no es JSON válido"

# Sin CLAUDE_CONFIG_DIR, la configuración de usuario es la de ~/.claude
mk_git_workspace
mkdir -p "$WS.home/.claude"; printf '{"disableAllHooks": true}\n' >"$WS.home/.claude/settings.json"
run_setup CLAUDE_CONFIG_DIR= HOME="$WS.home"
assert_exit 3 || fail_case "con disableAllHooks: true en ~/.claude/settings.json debería terminar con 3: $RH_ERR"
assert_out_contains "$WS.home/.claude/settings.json" || fail_case "la salida debería nombrar la configuración de usuario"
rm -rf "$WS.home"; cleanup_git_workspace
