#!/usr/bin/env bash
# SC-sdk-setup-10: el instalador no sirve para descablear el Centinela. Con un jq que «fusiona»
# devolviendo un settings.json sin hooks, el cableado no se pierde (queda pendiente); un jq que
# está dentro del repo destino se ignora, venga por SENTINEL_SETUP_JQ o por el PATH (A4, V1, V3).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; rm -rf "$WS.bin"; cleanup_git_workspace; exit 1; }
S="$WS/.claude/settings.json"

run_setup
assert_exit 0 || fail_case "la instalación en un repo limpio debería terminar con 0"
orig="$(cat "$S")"

# Un jq falso: al fusionar (--argjson) devuelve un settings.json sin hooks; lo demás, como cat
mkdir -p "$WS.bin"
cat >"$WS.bin/jq" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do [ "$a" = --argjson ] && { echo '{"hooks":{}}'; exit 0; }; done
case " $* " in *" -e "*) echo true; exit 0 ;; esac
last="${!#}"; if [ -f "$last" ]; then cat "$last"; else cat; fi
EOF
chmod +x "$WS.bin/jq"

# a) fuera del repo: el resultado no conserva el cableado → no se escribe
run_setup SENTINEL_SETUP_JQ="$WS.bin/jq"
assert_exit 3 || fail_case "con un jq que pierde el cableado debería terminar con 3"
[ "$(cat "$S")" = "$orig" ] || fail_case "setup escribió un settings.json sin el cableado del Centinela"
assert_out_contains "no conserva el cableado" || fail_case "la salida no explica por qué no se fusionó"

# b) dentro del repo, por SENTINEL_SETUP_JQ y por el PATH: se ignora
mkdir -p "$WS/tools"; cp "$WS.bin/jq" "$WS/tools/jq"
run_setup SENTINEL_SETUP_JQ="$WS/tools/jq"
assert_exit 0 || fail_case "con un jq dentro del repo (ignorado) y el cableado puesto debería terminar con 0: $RH_ERR"
[ "$(cat "$S")" = "$orig" ] || fail_case "setup usó un jq de dentro del repo"
assert_out_contains "dentro del repo" || fail_case "la salida no avisa de que ignora el jq del repo"
run_setup PATH="$WS/tools:$PATH"
assert_exit 0 || fail_case "con un jq del repo en el PATH (ignorado) debería terminar con 0: $RH_ERR"
[ "$(cat "$S")" = "$orig" ] || fail_case "setup usó un jq del repo encontrado por el PATH"

# c) fuera del repo, un jq que conserva los textos del cableado pero lo saca de su evento (todo en
#    SessionStart, nada en PreToolUse): la comprobación es de estructura, así que no se escribe
jq '{hooks: {SessionStart: [.hooks[][]]}}' "$REPO_ROOT/.claude/settings.json" >"$WS.bin/moved.json" \
  || fail_case "no se pudo preparar el resultado desplazado"
cat >"$WS.bin/jq-moved" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do [ "\$a" = --argjson ] && { cat "$WS.bin/moved.json"; exit 0; }; done
case " \$* " in *" -e "*) echo true; exit 0 ;; esac
last="\${!#}"; if [ -f "\$last" ]; then cat "\$last"; else cat; fi
EOF
chmod +x "$WS.bin/jq-moved"
run_setup SENTINEL_SETUP_JQ="$WS.bin/jq-moved"
assert_exit 3 || fail_case "con un resultado que saca el Centinela de PreToolUse debería terminar con 3"
[ "$(cat "$S")" = "$orig" ] || fail_case "setup escribió un settings.json con el Centinela fuera de su evento"

rm -rf "$WS.bin"
cleanup_git_workspace
