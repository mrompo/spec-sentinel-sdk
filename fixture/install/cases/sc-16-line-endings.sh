#!/usr/bin/env bash
# SC-sdk-setup-16: con la conversión a CRLF de Git for Windows (core.autocrlf=true), lo que ejecuta
# bash o lee el Centinela llega con LF. El SDK trae un .gitattributes y setup añade al del
# consumidor «sentinel/** text eol=lf»: en un clon así, el Centinela deja pasar lo inocuo y la
# Esclusa acepta un commit conforme (P5-1). Una copia del SDK con CRLF no instala nada.
# El SDK se clona desde su último commit: el .gitattributes cuenta cuando está versionado.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
sdk="$WS.sdk"; clone="$WS.clone"
fail_case() { echo "    $1" >&2; rm -rf "$sdk" "$clone"; cleanup_git_workspace; exit 1; }
has_cr() { LC_ALL=C grep -q "$(printf '\r')" "$1"; }

# 1) El SDK clonado con CRLF: setup llega con LF y arranca
git clone -q -c core.autocrlf=true --depth 1 "file://$REPO_ROOT" "$sdk" || fail_case "no se pudo clonar el SDK"
for f in ai-specs/skills/setup/setup.sh sentinel/hooks/sentinel-guard.sh sentinel/githooks/commit-msg sentinel/policy.default.yaml; do
  has_cr "$sdk/$f" && fail_case "clonado con core.autocrlf=true, $f tiene CRLF (falta el .gitattributes del SDK)"
done
_capture env "$(gl_ok)" bash "$sdk/ai-specs/skills/setup/setup.sh" "$WS"
assert_exit 0 || fail_case "setup desde un SDK clonado con core.autocrlf=true debería terminar con 0: $RH_ERR"
grep -qxF "sentinel/** text eol=lf" "$WS/.gitattributes" || fail_case "setup no añadió «sentinel/** text eol=lf» al .gitattributes del consumidor"

# 2) El clon CRLF de un compañero: el Centinela deja pasar lo inocuo y la Esclusa acepta un
#    commit conforme
git_in_ws add -A -- . ':!.gl-ok' && ws_commit "chore: instala spec-sentinel" || fail_case "no se pudo versionar la instalación: $RH_ERR"
git clone -q -c core.autocrlf=true "$WS" "$clone" || fail_case "no se pudo clonar el consumidor"
for f in sentinel/hooks/sentinel-guard.sh sentinel/githooks/commit-msg sentinel/githooks/lib/breakglass.sh; do
  has_cr "$clone/$f" && fail_case "en el clon con core.autocrlf=true, $f tiene CRLF"
done
out="$(cd "$clone" && printf '{"tool_name":"Bash","tool_input":{"command":"true"}}' \
  | CLAUDE_PROJECT_DIR="$clone" bash "$clone/sentinel/hooks/sentinel-guard.sh" 2>&1)" \
  || fail_case "en el clon con core.autocrlf=true, el Centinela deniega una acción inocua: $out"
git -C "$clone" config core.hooksPath sentinel/githooks
out="$(cd "$clone" && env "$(gl_ok)" git commit -q --allow-empty -m "feat: prueba en el clon" 2>&1)" \
  || fail_case "en el clon con core.autocrlf=true, la Esclusa rechaza un commit conforme: $out"
# setup en ese clon reconoce las líneas de .gitignore y .gitattributes aunque lleguen con CRLF:
# no repite nada ni cambia nada (P6-3)
_capture env "$(gl_ok)" bash "$sdk/ai-specs/skills/setup/setup.sh" "$clone"
assert_exit 0 || fail_case "setup en el clon con core.autocrlf=true debería terminar con 0: $RH_ERR"
[ -z "$(git -C "$clone" status --porcelain)" ] \
  || fail_case "setup en el clon con core.autocrlf=true cambió ficheros: $(git -C "$clone" status --porcelain | tr '\n' ' ')"

# 2b) una regla posterior del .gitattributes que anula la de sentinel/ deja pendiente (A6-4)
printf 'sentinel/hooks/* eol=crlf\n' >>"$WS/.gitattributes"
_capture env "$(gl_ok)" bash "$sdk/ai-specs/skills/setup/setup.sh" "$WS"
assert_exit 3 || fail_case "con una regla posterior que anula eol=lf en sentinel/ debería terminar con 3: $RH_ERR"
assert_out_contains "LF" || fail_case "el pendiente debería decir que sentinel/ no queda en LF"

# 3) Una copia del SDK con un fichero distribuido en CRLF: setup no instala nada
rm -rf "$clone"; cleanup_git_workspace; mk_git_workspace
f="$sdk/sentinel/hooks/post-edit.sh"
awk '{ printf "%s\r\n", $0 }' "$f" >"$f.crlf" && mv "$f.crlf" "$f"
before="$(ws_snapshot)"
_capture env "$(gl_ok)" bash "$sdk/ai-specs/skills/setup/setup.sh" "$WS"
assert_exit 1 || fail_case "desde un SDK con un fichero en CRLF debería terminar con 1: $RH_ERR"
assert_out_contains "CRLF" || fail_case "la salida debería explicar que hay finales de línea CRLF"
[ "$before" = "$(ws_snapshot)" ] || fail_case "desde un SDK con CRLF no debería escribirse nada"
# La orden que da setup deja de verdad la copia en LF, también la de un clon anterior al
# .gitattributes que se actualizó (A6-2 = P6-2)
fixcmd="$(printf '%s\n' "$RH_ERR" | sed -n 's/.*\(git rm -r -q --cached \. .*\)$/\1/p' | head -1)"
[ -n "$fixcmd" ] || fail_case "la salida debería dar la orden «git rm -r -q --cached . …» para pasar el SDK a LF"
( cd "$sdk" && eval "$fixcmd" ) || fail_case "la orden que da setup falló: $fixcmd"
has_cr "$f" && fail_case "tras la orden que da setup, $f sigue con CRLF"
_capture env "$(gl_ok)" bash "$sdk/ai-specs/skills/setup/setup.sh" "$WS"
assert_exit 0 || fail_case "tras la orden que da setup, debería instalar y terminar con 0: $RH_ERR"

rm -rf "$sdk"
cleanup_git_workspace
