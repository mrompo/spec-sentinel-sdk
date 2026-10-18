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

# 3) Una copia del SDK con un fichero distribuido en CRLF: setup no instala nada
rm -rf "$clone"; cleanup_git_workspace; mk_git_workspace
f="$sdk/sentinel/hooks/post-edit.sh"
awk '{ printf "%s\r\n", $0 }' "$f" >"$f.crlf" && mv "$f.crlf" "$f"
before="$(ws_snapshot)"
_capture env "$(gl_ok)" bash "$sdk/ai-specs/skills/setup/setup.sh" "$WS"
assert_exit 1 || fail_case "desde un SDK con un fichero en CRLF debería terminar con 1: $RH_ERR"
assert_out_contains "CRLF" || fail_case "la salida debería explicar que hay finales de línea CRLF"
[ "$before" = "$(ws_snapshot)" ] || fail_case "desde un SDK con CRLF no debería escribirse nada"

rm -rf "$sdk"
cleanup_git_workspace
