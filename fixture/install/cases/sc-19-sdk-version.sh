#!/usr/bin/env bash
# SC-sdk-version-01..05: setup deja en sentinel/.sdk-version el commit de la copia del SDK y si su
# árbol tenía cambios sin commitear. Solo instala sin más si el commit instalado es antecesor del
# de la copia (o el mismo) y la copia está limpia; si no (más vieja, de otra rama, sin git, con un
# fichero de versión ilegible o con cambios), no escribe nada, dice qué hay y qué instalaría, y
# sale con 1. La persona lo confirma con --downgrade.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
V="$WS/sentinel/.sdk-version"
nogit="$SDK_TMP/sin-git"
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
sdk_git() { git -C "$SDK_SRC" "$@"; }
# setup_from <setup.sh> [opciones…] → setup desde otra copia, o con opciones, sobre el workspace
setup_from() { local s="$1"; shift; _capture env "$(gl_ok)" bash "$s" "$@" "$WS"; }
# refused <qué> → setup no escribió nada, salió con 1 y dijo cómo confirmarlo
refused() {
  assert_exit 1 || fail_case "$1: setup debería negarse y terminar con 1"
  [ "$(ws_snapshot)" = "$before" ] || fail_case "$1: setup no debería escribir nada"
  assert_out_contains "--downgrade" || fail_case "$1: la salida debería decir cómo confirmarlo (--downgrade): $RH_ERR"
}
C1="$(sdk_git rev-parse HEAD)"

# ── SC-01: la primera instalación deja la versión y la nombra entre lo que hay que versionar ──
run_setup
assert_exit 0 || fail_case "la primera instalación debería terminar con 0: $RH_ERR"
[ -f "$V" ] || fail_case "la instalación no dejó sentinel/.sdk-version"
grep -qx "commit=$C1" "$V" || fail_case "sentinel/.sdk-version debería decir commit=$C1: $(cat "$V")"
grep -qx "dirty=no" "$V" || fail_case "sentinel/.sdk-version debería decir dirty=no: $(cat "$V")"
assert_out_contains "sentinel/.sdk-version" || fail_case "setup debería nombrar sentinel/.sdk-version entre lo que hay que versionar: $RH_ERR"
git_in_ws check-ignore -q sentinel/.sdk-version && fail_case "sentinel/.sdk-version no puede estar ignorado"

# ── SC-02: una copia más nueva instala y actualiza el fichero ────────────────────────────────
sdk_git commit -q --allow-empty -m "más nuevo"
C2="$(sdk_git rev-parse HEAD)"
run_setup
assert_exit 0 || fail_case "desde una copia más nueva debería instalar: $RH_ERR"
grep -qx "commit=$C2" "$V" || fail_case "tras actualizar, sentinel/.sdk-version debería decir commit=$C2: $(cat "$V")"

# Sin fichero de versión (una instalación anterior a sdk-version) también instala, y lo dice
rm -f "$V"
run_setup
assert_exit 0 || fail_case "sin sentinel/.sdk-version debería instalar: $RH_ERR"
assert_out_contains "no constaba" || fail_case "sin sentinel/.sdk-version, la salida debería decir que no constaba versión: $RH_ERR"
grep -qx "commit=$C2" "$V" || fail_case "sin fichero previo debería registrar commit=$C2"

# ── SC-03: una copia más vieja, de otra rama, sin git o un fichero ilegible no instalan ──────
before="$(ws_snapshot)"
sdk_git checkout -q --detach "$C1"
run_setup
refused "desde una copia más vieja"
assert_out_contains "${C2:0:7}" || fail_case "la salida debería decir la versión instalada (${C2:0:7}): $RH_ERR"
assert_out_contains "${C1:0:7}" || fail_case "la salida debería decir la versión que instalaría (${C1:0:7}): $RH_ERR"
assert_out_contains "git -C" || fail_case "la salida debería actualizar la copia del SDK (git -C <copia> pull), no el proyecto: $RH_ERR"

sdk_git checkout -q -b otra-rama "$C1" && sdk_git commit -q --allow-empty -m "otra rama"
run_setup
refused "desde una copia de otra rama"

# Una copia sin git propio, aunque esté dentro de otro repo: el de fuera, en el commit instalado
# y sin cambios (la copia está excluida), no es su versión
sdk_git checkout -q --detach "$C2"
mkdir -p "$nogit" && ( cd "$SDK_SRC" && tar --exclude=./.git -cf - . ) | ( cd "$nogit" && tar -xf - )
mv "$nogit" "$SDK_SRC/vendor-sdk" && nogit="$SDK_SRC/vendor-sdk"
printf 'vendor-sdk/\n' >>"$SDK_SRC/.git/info/exclude"
setup_from "$nogit/ai-specs/skills/setup/setup.sh"
refused "desde una copia que no es un clon de git"
assert_out_contains "no es un clon de git" || fail_case "la salida debería decir que la copia no es un clon de git: $RH_ERR"

cp "$V" "$V.bien" && printf 'basura\n' >"$V"
before="$(ws_snapshot)"
run_setup
refused "con un sentinel/.sdk-version ilegible"
assert_out_contains "no se puede leer" || fail_case "la salida debería decir que la versión instalada no se puede leer: $RH_ERR"
mv "$V.bien" "$V"

# ── SC-04: una copia con cambios sin commitear no instala, aunque su commit sea el mismo ──────
before="$(ws_snapshot)"
printf '\n# cambio sin commitear\n' >>"$SDK_SRC/sentinel/README.md"
run_setup
refused "desde una copia con un cambio sin commitear"
assert_out_contains "sin commitear" || fail_case "la salida debería decir que la copia tiene cambios sin commitear: $RH_ERR"
sdk_git checkout -q -- sentinel/README.md
# Si git status falla (aquí, con el índice dañado), no se sabe si hay cambios: tampoco instala
cp "$SDK_SRC/.git/index" "$SDK_TMP/index.bien" && printf 'basura' >"$SDK_SRC/.git/index"
run_setup
refused "desde una copia en la que git status falla"
assert_out_contains "git status" || fail_case "la salida debería decir que git status falla en la copia: $RH_ERR"
mv "$SDK_TMP/index.bien" "$SDK_SRC/.git/index"
printf '#!/bin/sh\n' >"$SDK_SRC/sentinel/hooks/nuevo.sh"
run_setup
refused "desde una copia con un fichero sin versionar en lo distribuido"
assert_out_contains "sentinel/hooks/nuevo.sh" || fail_case "la salida debería nombrar el fichero sin versionar: $RH_ERR"

# ── SC-05: con --downgrade, instala, avisa y registra lo que ha quedado ──────────────────────
setup_from "$SETUP" --downgrade
assert_exit 0 || fail_case "con --downgrade debería instalar la copia con cambios: $RH_ERR"
grep -qx "dirty=yes" "$V" || fail_case "con cambios sin commitear, sentinel/.sdk-version debería decir dirty=yes: $(cat "$V")"
rm -f "$SDK_SRC/sentinel/hooks/nuevo.sh"

sdk_git checkout -q --detach "$C1"
setup_from "$SETUP" --downgrade
assert_exit 0 || fail_case "con --downgrade debería instalar la copia más vieja: $RH_ERR"
assert_out_contains "${C1:0:7}" || fail_case "con --downgrade, la salida debería avisar de la versión que queda: $RH_ERR"
grep -qx "commit=$C1" "$V" || fail_case "tras --downgrade, sentinel/.sdk-version debería decir commit=$C1: $(cat "$V")"
grep -qx "dirty=no" "$V" || fail_case "tras --downgrade desde una copia limpia, debería decir dirty=no"

# ── SC-01: la versión viaja con el repo, así que setup avisa si el .gitignore la deja fuera ───
sdk_git checkout -q --detach "$C2"
cp "$WS/.gitignore" "$WS/.gitignore.bien" && printf 'sentinel/.sdk-version\n' >>"$WS/.gitignore"
run_setup
assert_exit 3 || fail_case "con sentinel/.sdk-version ignorado, setup debería terminar con pendientes (3): $RH_ERR"
assert_out_contains "!sentinel/.sdk-version" || fail_case "setup debería dar la excepción que reincluye sentinel/.sdk-version: $RH_ERR"
mv "$WS/.gitignore.bien" "$WS/.gitignore"

# ── SC-01: sobre el propio SDK no se copia nada, y tampoco se escribe la versión ─────────────
_capture env "$(gl_ok)" bash "$SETUP" "$SDK_SRC"
[ -e "$SDK_SRC/sentinel/.sdk-version" ] && fail_case "sobre el propio SDK no debería escribirse sentinel/.sdk-version"

# ── Panel de sdk-version (ronda 2) ───────────────────────────────────────────────────────────
run_setup
assert_exit 0 || fail_case "desde la copia limpia en C2 debería instalar: $RH_ERR"

# SC-04 (P2): lo que no se instala no cuenta como cambio de la copia, por ejemplo una carpeta del
# editor sin versionar
mkdir -p "$SDK_SRC/.vscode" && printf '{}\n' >"$SDK_SRC/.vscode/settings.json"
run_setup
assert_exit 0 || fail_case "con un .vscode/ sin versionar en la copia, setup debería instalar: $RH_ERR"
grep -qx "dirty=no" "$V" || fail_case "un .vscode/ sin versionar no es un cambio de lo que se instala: $(cat "$V")"
rm -rf "$SDK_SRC/.vscode"

# SC-04 (A2): lo que se instala cuenta aunque git status no lo enseñe, con
# status.showUntrackedFiles=no o ignorado
before="$(ws_snapshot)"
sdk_git config status.showUntrackedFiles no
printf '#!/bin/sh\n' >"$SDK_SRC/sentinel/hooks/nuevo.sh"
run_setup
refused "con un fichero sin versionar en lo distribuido y status.showUntrackedFiles=no"
assert_out_contains "sentinel/hooks/nuevo.sh" || fail_case "la salida debería nombrar el fichero sin versionar: $RH_ERR"
rm -f "$SDK_SRC/sentinel/hooks/nuevo.sh"; sdk_git config --unset status.showUntrackedFiles
printf 'pre-commit.orig\n' >>"$SDK_SRC/.git/info/exclude"
cp "$SDK_SRC/sentinel/githooks/pre-commit" "$SDK_SRC/sentinel/githooks/pre-commit.orig"
run_setup
refused "con un fichero ignorado en lo distribuido"
assert_out_contains "sentinel/githooks/pre-commit.orig" || fail_case "la salida debería nombrar el fichero ignorado: $RH_ERR"
rm -f "$SDK_SRC/sentinel/githooks/pre-commit.orig"

# SC-03 (P4): una copia superficial más nueva no tiene el commit instalado: lo dice y propone
# --unshallow, no git pull. La copia tiene ya la Esclusa activa (setup sobre el propio SDK)
sdk_git checkout -q -b panel "$C2" && sdk_git commit -q --allow-empty -m "chore: más nuevo" \
  || fail_case "no se pudo hacer el commit más nuevo en la copia"
git clone -q --depth 1 -b panel "file://$SDK_SRC" "$SDK_TMP/superficial" || fail_case "no se pudo hacer el clon superficial"
setup_from "$SDK_TMP/superficial/ai-specs/skills/setup/setup.sh"
refused "desde un clon superficial más nuevo"
assert_out_contains "--unshallow" || fail_case "con un clon superficial, la salida debería proponer git fetch --unshallow: $RH_ERR"
rm -rf "$SDK_TMP/superficial"; sdk_git checkout -q --detach "$C2"

# A6 = V6: un sentinel/.sdk-version que no es un fichero normal no se lee ni se escribe, tampoco
# con --downgrade: una carpeta no cuenta como «no constaba», y un enlace llevaría la escritura
# fuera del repo
mv "$V" "$V.bien" && mkdir "$V"
before="$(ws_snapshot)"
run_setup
assert_exit 1 || fail_case "con sentinel/.sdk-version como carpeta, setup debería negarse: $RH_ERR"
[ "$(ws_snapshot)" = "$before" ] || fail_case "con sentinel/.sdk-version como carpeta, setup no debería escribir nada"
assert_out_contains "no es un fichero normal" || fail_case "la salida debería decir que sentinel/.sdk-version no es un fichero normal: $RH_ERR"
rmdir "$V" && ln -s "$SDK_TMP/fuera" "$V"
before="$(ws_snapshot)"
setup_from "$SETUP" --downgrade
assert_exit 1 || fail_case "con sentinel/.sdk-version como enlace, setup debería negarse también con --downgrade: $RH_ERR"
[ -e "$SDK_TMP/fuera" ] && fail_case "setup no debería escribir fuera del repo siguiendo el enlace"
assert_out_contains "enlace simbólico" || fail_case "la salida debería decir que sentinel/.sdk-version es un enlace simbólico: $RH_ERR"
rm "$V" && mv "$V.bien" "$V"

# SC-03 (A1): una copia sin git no instala sin --downgrade, tampoco sin versión anterior, y con
# --downgrade no registra «dirty=no», porque no se sabe
rm -f "$V"; before="$(ws_snapshot)"
setup_from "$nogit/ai-specs/skills/setup/setup.sh"
refused "desde una copia sin git, sin versión instalada"
assert_out_contains "no es un clon de git" || fail_case "la salida debería decir que la copia no es un clon de git: $RH_ERR"
setup_from "$nogit/ai-specs/skills/setup/setup.sh" --downgrade
assert_exit 0 || fail_case "desde una copia sin git, con --downgrade, debería instalar: $RH_ERR"
grep -qx "commit=desconocido" "$V" || fail_case "desde una copia sin git, sentinel/.sdk-version debería decir commit=desconocido: $(cat "$V")"
grep -qx "dirty=no" "$V" && fail_case "desde una copia sin git no se sabe si hay cambios: no debería registrar dirty=no"
# P1 = V7: después, desde un clon de git limpio, instala con aviso, como sin versión anterior
run_setup
assert_exit 0 || fail_case "tras instalar desde una copia sin git, un clon limpio debería instalar sin --downgrade: $RH_ERR"
assert_out_contains "copia del SDK sin git" || fail_case "la salida debería decir que la versión anterior se instaló desde una copia sin git: $RH_ERR"
grep -qx "commit=$C2" "$V" || fail_case "desde el clon limpio debería registrar commit=$C2: $(cat "$V")"

cleanup_git_workspace
exit 0
