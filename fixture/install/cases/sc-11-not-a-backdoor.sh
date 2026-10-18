#!/usr/bin/env bash
# SC-sdk-setup-10: el instalador no sirve para descablear el Centinela. Un jq que está dentro del
# repo destino se ignora, venga por SENTINEL_SETUP_JQ o por el PATH (A4, V1, V3). Un resultado de
# la fusión que pierde el cableado, lo saca de su evento, cambia algo fuera de «hooks» o no es JSON
# válido no se escribe: queda pendiente (P3-1, A3-1, V4-1, V4-prev-A3-prev-A2-prevA4). Un jq de
# fuera del repo manipulado para falsear también la comprobación es el límite «jq manipulado».
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; rm -rf "$WS.bin"; cleanup_git_workspace; exit 1; }
S="$WS/.claude/settings.json"; mkdir -p "$WS/.claude"
printf '{"permissions":{"deny":["Bash(rm:*)"]}}\n' >"$S"

run_setup
assert_exit 0 || fail_case "la instalación en un repo limpio debería terminar con 0: $RH_ERR"
orig="$(cat "$S")"
REAL_JQ="$(command -v jq)"

# fake_jq <nombre> <resultado> → un jq que es el real salvo en la fusión (la llamada que pasa los
# scripts del SDK), donde devuelve <resultado>: un jq con un fallo, no uno que falsea todo
mkdir -p "$WS.bin"
fake_jq() {
  printf '%s\n' "$2" >"$WS.bin/$1.out"
  cat >"$WS.bin/$1" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do [ "\$a" = scripts ] && { cat "$WS.bin/$1.out"; exit 0; }; done
exec "$REAL_JQ" "\$@"
EOF
  chmod +x "$WS.bin/$1"
}

# a) dentro del repo, por SENTINEL_SETUP_JQ: se ignora y se usa el del PATH (A5-4)
fake_jq lost '{"hooks":{}}'
mkdir -p "$WS/tools"; cp "$WS.bin/lost" "$WS/tools/jq"
run_setup SENTINEL_SETUP_JQ="$WS/tools/jq"
assert_exit 0 || fail_case "con SENTINEL_SETUP_JQ dentro del repo debería usar el del PATH y terminar con 0: $RH_ERR"
[ "$(cat "$S")" = "$orig" ] || fail_case "setup usó un jq de dentro del repo"
assert_out_contains "dentro del repo" || fail_case "la salida no avisa de que ignora el jq del repo"

# b) dentro del repo, por el PATH: se ignora y se usa el siguiente jq del PATH
run_setup PATH="$WS/tools:$PATH"
assert_exit 0 || fail_case "con un jq del repo delante en el PATH debería usar el siguiente y terminar con 0: $RH_ERR"
[ "$(cat "$S")" = "$orig" ] || fail_case "setup usó un jq del repo encontrado por el PATH"
assert_out_contains "dentro del repo" || fail_case "la salida no avisa de que ignora el jq del repo"

# b2) un enlace del repo a un jq de fuera (un bin/ o .venv/bin del repo en el PATH) tampoco se
#     usa: lo que el agente escribe es el enlace, dentro del repo (A5-1)
mkdir -p "$WS/bin"; ln -s "$WS.bin/lost" "$WS/bin/jq"
run_setup PATH="$WS/bin:$PATH"
assert_exit 0 || fail_case "con un enlace del repo a un jq de fuera debería usar el siguiente del PATH y terminar con 0: $RH_ERR"
[ "$(cat "$S")" = "$orig" ] || fail_case "setup usó un jq al que se llega por un enlace dentro del repo"
assert_out_contains "dentro del repo" || fail_case "la salida no avisa de que ignora el enlace del repo"

# b3) la configuración de jq de la persona (~/.jq) no cambia lo que hacen los programas de setup:
#     con el jq legítimo, una definición ahí no puede quitar el cableado ni esconder lo que apaga
#     los hooks (V5-3)
mkdir -p "$WS.home"
printf 'def to_entries: [];\n' >"$WS.home/.jq"
run_setup HOME="$WS.home"
assert_exit 0 || fail_case "con un ~/.jq que redefine to_entries debería terminar con 0 sin tocar nada: $RH_ERR"
[ "$(cat "$S")" = "$orig" ] || fail_case "un ~/.jq cambió el settings.json que escribe setup"
printf 'def has($k): false; def startswith($s): false;\n' >"$WS.home/.jq"
printf '{"disableAllHooks": true}\n' >"$WS/.claude/settings.local.json"
run_setup HOME="$WS.home"
assert_exit 3 || fail_case "con un ~/.jq que redefine has, disableAllHooks en el local debería seguir pendiente: $RH_ERR"
rm -rf "$WS.home" "$WS/.claude/settings.local.json"

# c) fuera del repo, una fusión que no pasa la comprobación: no se escribe
H="$(jq -c .hooks "$REPO_ROOT/.claude/settings.json")"
P='"permissions":{"deny":["Bash(rm:*)"]}'
while IFS='|' read -r name what out; do
  [ -n "$name" ] || continue
  fake_jq "$name" "${out//@H@/$H}"
  run_setup SENTINEL_SETUP_JQ="$WS.bin/$name"
  assert_exit 3 || fail_case "con una fusión que $what debería terminar con 3: $RH_ERR"
  [ "$(cat "$S")" = "$orig" ] || fail_case "setup escribió una fusión que $what"
  assert_out_contains "el resultado de la fusión" || fail_case "con una fusión que $what, la salida no explica por qué no se escribió"
done <<EOF
lost|pierde el cableado|{$P,"hooks":{}}
moved|saca el Centinela de su evento|{$P,"hooks":{"SessionStart":$(jq -c '[.hooks[][]]' "$REPO_ROOT/.claude/settings.json")}}
dup|deja una segunda clave «hooks» vacía|{$P,"hooks":@H@,"hooks":{}}
off|añade disableAllHooks|{$P,"hooks":@H@,"disableAllHooks":true}
env|añade un env con SENTINEL_*|{$P,"hooks":@H@,"env":{"SENTINEL_POLICY":"/dev/null"}}
perm|pierde los permisos del consumidor|{"hooks":@H@}
comma|no es JSON válido|{$P,"hooks":@H@,}
nan|tiene un NaN|{$P,"hooks":@H@,"x":NaN}
EOF

rm -rf "$WS.bin"
cleanup_git_workspace
