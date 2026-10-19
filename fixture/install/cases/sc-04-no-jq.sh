#!/usr/bin/env bash
# SC-sdk-setup-04: sin jq fuera del repo destino, setup termina con 1 sin escribir nada y da la
# instrucción de instalación (jq es obligatorio desde la cuarta revisión de la PR 3/3).
# SC-sdk-setup-10: un .claude/settings.json que no es JSON válido no cuenta como cableado,
# tampoco con lo que jq acepta y JSON.parse no: pendiente que dice que no es JSON válido, sin
# proponer sustituir entradas, y el fichero no se toca (A4-prev-P3-1 = P4-1, P4-2 = A4-4).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

before="$(ws_snapshot)"
run_setup SENTINEL_SETUP_JQ=/nonexistent/jq
assert_exit 1 || fail_case "sin jq debería terminar con 1 (error, nada instalado): $RH_ERR"
[ "$before" = "$(ws_snapshot)" ] || fail_case "sin jq no debería escribirse nada"
assert_out_contains "brew install jq" || fail_case "sin jq, la salida debería dar la instrucción de instalación"
cleanup_git_workspace

# El cableado del SDK exacto más un fallo típico de editar a mano. jq rechaza los primeros; los
# segundos los acepta jq y JSON.parse no (Claude Code descartaría el fichero entero)
H="$(jq -c .hooks "$REPO_ROOT/.claude/settings.json")"
while IFS='|' read -r what body; do
  [ -n "$what" ] || continue
  mk_git_workspace
  S="$WS/.claude/settings.json"; mkdir -p "$WS/.claude"
  content="$(printf '%b' "$body")"; printf '%s\n' "${content//@H@/$H}" >"$S"
  orig="$(cksum <"$S")"
  run_setup
  assert_exit 3 || fail_case "con un settings.json con $what debería terminar con 3: $RH_ERR"
  [ "$(cksum <"$S")" = "$orig" ] || fail_case "un settings.json con $what no se toca"
  assert_out_contains "no es JSON válido" || fail_case "con $what, la salida debería decir que no es JSON válido"
  assert_out_lacks "ya cableado" || fail_case "con $what no debería decir «ya cableado»"
  assert_out_lacks "Sustituye" || fail_case "con $what no debería pedir sustituir entradas"
  cleanup_git_workspace
done <<'EOF'
una coma final|{"hooks":@H@,}
una coma que falta|{"hooks":@H@ "model":"x"}
un comentario|{"hooks":@H@ // comentario\n}
un literal mal escrito|{"hooks":@H@,"x":tru}
dos objetos|{"hooks":@H@}{}
algo detrás del objeto|{"hooks":@H@}}
NaN|{"hooks":@H@,"x":NaN}
Infinity|{"hooks":@H@,"x":-Infinity}
un cero a la izquierda|{"hooks":@H@,"x":01}
un número con +|{"hooks":@H@,"x":+1}
un número sin parte entera|{"hooks":@H@,"x":.5}
un número sin decimales tras el punto|{"hooks":@H@,"x":5.}
una marca BOM|\xef\xbb\xbf{"hooks":@H@}
EOF

# Bytes NUL al final y un byte de control dentro de una cadena: algunos jq los aceptan y
# JSON.parse no (A5-2, V5-8). Y el pendiente dice la línea de lo que jq acepta y JSON no (A5-6)
mk_git_workspace
S="$WS/.claude/settings.json"; mkdir -p "$WS/.claude"
printf '{"hooks":%s}\n' "$H" >"$S"; printf '\000\000\000' >>"$S"
run_setup
assert_exit 3 || fail_case "con bytes NUL al final debería terminar con 3: $RH_ERR"
assert_out_contains "no es JSON válido" || fail_case "con bytes NUL, la salida debería decir que no es JSON válido"
printf '{"hooks":%s,"model":"x\037y"}\n' "$H" >"$S"
run_setup
assert_exit 3 || fail_case "con un byte de control en una cadena debería terminar con 3: $RH_ERR"
# jq 1.7 o posterior ya rechaza ese byte, así que el léxico de setup (JSON_LEX) se prueba
# directamente: con jq 1.6, que lo acepta, es lo único que lo detecta (A6-4)
lex="$(sed -n "/^JSON_LEX='/,/^END { exit failed }'/p" "$SETUP" | sed -e "1s/^JSON_LEX='//" -e "\$s/'\$//")"
[ -n "$lex" ] || fail_case "no se encuentra el léxico JSON_LEX en setup.sh"
printf '{"a":"x\037y"}\n' >"$WS/ctl.json"
out="$(LC_ALL=C awk "$lex" "$WS/ctl.json")" && fail_case "el léxico de setup acepta un byte de control dentro de una cadena"
case "$out" in *"byte de control"*) ;; *) fail_case "el léxico debería decir que hay un byte de control (dice: $out)" ;; esac
printf '{"a":"x\\ty","b":"\\u0001"}\n' >"$WS/ctl.json"
LC_ALL=C awk "$lex" "$WS/ctl.json" >/dev/null || fail_case "el léxico de setup rechaza escapes válidos dentro de una cadena"
printf '{"hooks":%s,\n"x":\nNaN}\n' "$H" >"$S"
run_setup
assert_exit 3 || fail_case "con un NaN en la línea 3 debería terminar con 3: $RH_ERR"
assert_out_contains "línea 3" || fail_case "con un NaN, la salida debería decir en qué línea"
cleanup_git_workspace

# Una clave repetida es JSON válido: vale la última, como en Claude Code. Con el cableado en la
# última, está cableado; con él en la primera, no (se fusiona y lo de la última se conserva)
mk_git_workspace
S="$WS/.claude/settings.json"; mkdir -p "$WS/.claude"
printf '{"hooks":{},"hooks":%s}\n' "$H" >"$S"
run_setup
assert_exit 0 || fail_case "con el cableado en la última clave «hooks» debería terminar con 0: $RH_ERR"
printf '{"hooks":%s,\n "hooks":{"PostToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"echo prettier"}]}]}}\n' "$H" >"$S"
run_setup
assert_exit 0 || fail_case "con el cableado en la primera clave «hooks» debería fusionarse y terminar con 0: $RH_ERR"
[ "$(settings_count "$S" sentinel-guard)" -eq 1 ] || fail_case "tras fusionar, el Centinela debería quedar cableado una vez"
[ "$(settings_count "$S" prettier)" -eq 1 ] || fail_case "tras fusionar, se perdió el hook de la última clave «hooks»"
cleanup_git_workspace
