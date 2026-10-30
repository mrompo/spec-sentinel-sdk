#!/usr/bin/env bash
# SC-sentinel-paths-05: la llave autoriza la acción prevista. Lleva el motivo y `para: <acción>`
#   y solo la gasta la acción cuya descripción coincide exactamente; cualquier otra acción
#   bloqueada (de cualquier agente) sigue bloqueada y la llave se conserva. Sin `para:` no
#   autoriza nada. El aviso de bloqueo da la llave de esa acción lista para copiar: pegada tal
#   cual en una shell, la escribe (revisión de sentinel-paths, P4 = A6). Con SENTINEL_OVERRIDE
#   activo, la llave de otra acción se conserva (V4) y la de esta acción se gasta (revisión de
#   la #18).
# SC-sentinel-guard-08/09 (modificados): con su `para:` la acción pasa, se audita y la llave
#   desaparece; una llave solo con `para:` (sin motivo) no vale.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
trap cleanup_workspace EXIT
fail_case() { echo "    $1" >&2; exit 1; }

mk_workspace
mkdir -p "$WS/sentinel/hooks"
cp "$DEFAULT_POLICY" "$WS/sentinel/policy.default.yaml"
TOKEN="$WS/sentinel/.override"; LOG="$WS/sentinel/overrides.log"
guard() { RH_CWD="$WS" run_hook "$GUARD_HOOK" "$1" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$WS/sentinel/policy.default.yaml" SENTINEL_POLICY="$NO_POLICY" SENTINEL_OVERRIDE=""; }

AUTORIZADA='{"tool_name":"Write","tool_input":{"file_path":"sentinel/policy.yaml","content":"version: 1"}}'
OTRA='{"tool_name":"Bash","tool_input":{"command":"rm sentinel/hooks/sentinel-guard.sh"}}'

# El aviso de bloqueo da la llave de ESA acción, lista para copiar
guard "$OTRA"
assert_exit 2 || fail_case "sin llave debería bloquearse"
assert_err_contains "para: Bash:rm sentinel/hooks/sentinel-guard.sh" || fail_case "el aviso no da el para: de la acción"
assert_err_contains "sentinel/.override" || fail_case "el aviso no dice dónde va la llave"

# Otra acción bloqueada llega antes: no gasta la llave
printf 'parche de sentinel-paths\npara: Write:sentinel/policy.yaml\n' >"$TOKEN"
guard "$OTRA"
assert_exit 2 || fail_case "otra acción no debería pasar con la llave de la autorizada"
[ -s "$TOKEN" ] || fail_case "otra acción gastó la llave"
[ ! -e "$LOG" ] || fail_case "otra acción no debería registrarse"

# La autorizada pasa, se audita y la llave desaparece
guard "$AUTORIZADA"
assert_exit 0 || fail_case "la acción autorizada debería pasar"
[ ! -e "$TOKEN" ] || fail_case "la llave no se consumió"
grep -q "self-protection | Write:sentinel/policy.yaml | parche de sentinel-paths" "$LOG" 2>/dev/null \
  || fail_case "la bitácora no tiene regla, acción y motivo: $(cat "$LOG" 2>/dev/null)"

# Un solo uso: la misma acción vuelve a bloquearse
guard "$AUTORIZADA"
assert_exit 2 || fail_case "la llave debería ser de un solo uso"

# Coincidencia exacta: una acción que contiene la autorizada no es ella
printf 'mirar la política\npara: Bash:git diff x\n' >"$TOKEN"
guard '{"tool_name":"Bash","tool_input":{"command":"git diff x; rm sentinel/hooks/sentinel-guard.sh"}}'
assert_exit 2 || fail_case "una acción que solo contiene la autorizada no debería pasar"
[ -s "$TOKEN" ] || fail_case "la llave se gastó con una acción que no era la autorizada"

# Sin para: no autoriza nada (y el aviso lo explica)
printf 'hotfix INC-9\n' >"$TOKEN"
guard "$AUTORIZADA"
assert_exit 2 || fail_case "una llave sin para: no debería autorizar nada"
assert_err_contains "para:" || fail_case "el aviso no explica que falta para:"
[ -s "$TOKEN" ] || fail_case "una llave sin para: no debería gastarse"

# Solo para:, sin motivo: no vale
printf 'para: Write:sentinel/policy.yaml\n' >"$TOKEN"
guard "$AUTORIZADA"
assert_exit 2 || fail_case "una llave sin motivo no debería valer"
[ -s "$TOKEN" ] || fail_case "una llave sin motivo no debería gastarse"

# La de sesión (SENTINEL_OVERRIDE) no se ata: vale para cualquier acción, y la llave de otra acción
# no se gasta con ella (V4)
printf 'parche de sentinel-paths\npara: Write:sentinel/policy.yaml\n' >"$TOKEN"
RH_CWD="$WS" run_hook "$GUARD_HOOK" "$OTRA" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$WS/sentinel/policy.default.yaml" SENTINEL_POLICY="$NO_POLICY" SENTINEL_OVERRIDE="sesión de mantenimiento"
assert_exit 0 || fail_case "SENTINEL_OVERRIDE debería seguir valiendo para toda la sesión"
[ -s "$TOKEN" ] || fail_case "con SENTINEL_OVERRIDE, la llave de otra acción debería conservarse"
# La llave de ESTA acción sí se gasta, aunque la excepción salga de la sesión: si no, al quitar
# SENTINEL_OVERRIDE la acción se podría repetir con ella (revisión de la #18)
RH_CWD="$WS" run_hook "$GUARD_HOOK" "$AUTORIZADA" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$WS/sentinel/policy.default.yaml" SENTINEL_POLICY="$NO_POLICY" SENTINEL_OVERRIDE="sesión de mantenimiento"
assert_exit 0 || fail_case "con SENTINEL_OVERRIDE, la acción de la llave debería pasar"
[ ! -e "$TOKEN" ] || fail_case "con SENTINEL_OVERRIDE, la llave de esta misma acción debería gastarse"
rm -f "$TOKEN"

# key_block <aviso> → las líneas de la llave tal como salen en el aviso (de la que la escribe a la
# que la cierra), con el motivo puesto
key_block() {
  printf '%s\n' "$1" | sed -n "/^cat > .*<<'LLAVE'\$/,/^[[:space:]]*LLAVE/p" | sed 's/<motivo>/arreglo aprobado/'
}
# paste_key <aviso> <shell> → pega la llave del aviso en esa shell, desde una subcarpeta del
# workspace: una persona no tiene por qué estar en la raíz
paste_key() {
  key_block "$1" >"$WS.pegar"
  [ -s "$WS.pegar" ] || return 1
  mkdir -p "$WS/src/sub"
  ( cd "$WS/src/sub" && "$2" "$WS.pegar" </dev/null >/dev/null 2>&1 ); rm -f "$WS.pegar"
}
# Un proyecto en una carpeta con espacios y comillas: la llave pegada va a su sitio igual
NEW="$WS-la 'llave' \$x"; mv "$WS" "$NEW"; WS="$NEW"
TOKEN="$WS/sentinel/.override"; LOG="$WS/sentinel/overrides.log"
# La llave del aviso, pegada tal cual en bash o en sh desde una subcarpeta, queda en la raíz del
# proyecto con el motivo y el para: de la acción, y la autoriza (P4 = A6, revisión de la #18)
for sh in bash sh; do
  guard "$AUTORIZADA"
  assert_exit 2 || fail_case "sin llave debería bloquearse"
  if [ "$sh" = bash ]; then
    # El agente no puede ejecutar la llave del aviso: el comando escribe la llave del proyecto
    aviso="$RH_ERR"
    bloque="$(key_block "$aviso")"
    payload="$(jq -n --arg c "$bloque" '{tool_name: "Bash", tool_input: {command: $c}}')"
    [ -n "$bloque" ] && [ -n "$payload" ] || fail_case "no se pudo preparar el comando del aviso (¿falta jq?)"
    guard "$payload"
    assert_exit 2 || fail_case "el agente no debería poder escribir la llave con el comando del aviso"
    assert_err_contains "[self-protection]" || fail_case "el comando del aviso debería bloquearse por self-protection: $RH_ERR"
    RH_ERR="$aviso"
  fi
  paste_key "$RH_ERR" "$sh" || fail_case "el aviso no trae la llave"
  [ "$(cat "$TOKEN" 2>/dev/null)" = "$(printf 'arreglo aprobado\npara: Write:sentinel/policy.yaml')" ] \
    || fail_case "la llave pegada en $sh debería quedar con el motivo y el para:: $(cat "$TOKEN" 2>/dev/null)"
  guard "$AUTORIZADA"
  assert_exit 0 || fail_case "con la llave pegada en $sh, la acción debería pasar"
done
exit 0
