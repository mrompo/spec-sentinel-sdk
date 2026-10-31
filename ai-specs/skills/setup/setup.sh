#!/usr/bin/env bash
# setup.sh — instala el nivel Guardia (Centinela + Esclusa) en un repo con un solo comando.
#
#   bash <sdk>/ai-specs/skills/setup/setup.sh [raíz-del-repo]      (por defecto, el directorio actual)
#
# Lo invoca la skill `spec-sentinel-setup` (SKILL.md, al lado); también se puede ejecutar a mano.
# Idempotente: una segunda ejecución no cambia nada. Nunca pisa la configuración del consumidor:
#   - lo distribuido (hooks, githooks, lector del adaptador, policy.default.yaml) se instala o
#     actualiza, con backup si el fichero del consumidor difería;
#   - lo del consumidor (policy.yaml, overrides.log, stack.yaml) solo se crea si no existe;
#     policy.yaml nace sin reglas: las del SDK viven en policy.default.yaml y se evalúan antes;
#   - .claude/settings.json se fusiona con jq, que es obligatorio (sin él no se instala nada); si
#     la forma de «hooks» no permite fusionar, se dice qué evento corregir; si la fusión falla, se
#     deja sentinel/settings.fragment.json y se explica el paso manual;
#   - .gitignore y .gitattributes reciben las líneas que la instalación necesita (la llave, los
#     backups y lo personal fuera de git; sentinel/ siempre con LF);
#   - core.hooksPath solo se activa si el repo no usa ya otros git hooks; si los usa, se dan
#     las líneas que encadenan la Esclusa en ellos (chain.sh) y se reconoce cuando ya están.
# Los backups van a sentinel/.backup/<fecha>/ (fuera de git).
#
# Salida: 0 instalado · 3 instalado con pasos pendientes (se listan) · 1 error. Si falla una
# comprobación previa no se escribe nada; si falla a mitad, lo hecho se queda y reejecutar es seguro.
# Variables: SENTINEL_SETUP_JQ (binario de jq), SENTINEL_GITLEAKS_BIN y SENTINEL_OPENSPEC_BIN (los
# mismos que la Esclusa), CLAUDE_CONFIG_DIR (la configuración de usuario de Claude Code, como en
# Claude Code), SENTINEL_SETUP_MANAGED (la configuración gestionada; por defecto, la de la
# plataforma).
# Falsifica: SC-sdk-setup-01..18 (fixture/install/cases/).
set -uo pipefail

# cd -P primero: a través de un enlace a la skill (~/.claude/skills/spec-sentinel-setup) se sube
# desde la real. Sin dirname: hasta limpiar el PATH no se ejecuta ningún programa
case "${BASH_SOURCE[0]}" in */*) here="${BASH_SOURCE[0]%/*}" ;; *) here=. ;; esac
SDK_ROOT="$(cd -P "$here" && cd ../../.. && pwd -P)"
GITLEAKS="${SENTINEL_GITLEAKS_BIN:-gitleaks}"
HOOKS_PATH="sentinel/githooks"

pending=0
die()  { echo "✗ [setup] $1" >&2; exit 1; }
ok()   { echo "✓ $1"; }
note() { echo "· $1"; }
todo() { echo "⚠ PENDIENTE: $1"; pending=1; }

# dist_files → lo que el SDK distribuye (rutas relativas): lo que se copia y lo que tiene que
# poder versionarse
dist_files() {
  (cd "$SDK_ROOT" && find sentinel/README.md sentinel/policy.default.yaml sentinel/hooks sentinel/githooks sentinel/adapters \
     -type f ! -name '.*' ! -name stack.yaml ! -name stack.proposed.yaml | LC_ALL=C sort)
}

# ── Comprobaciones: nada se escribe hasta que todo cuadra ────────────────────────────────
[ -d "${1:-.}" ] || die "no existe el directorio ${1:-.}"
TARGET="$(cd "${1:-.}" && pwd -P)"

# Nada de lo que setup ejecuta puede venir del repo destino: el agente podría poner ahí un jq que
# «fusione» quitando el cableado, un bash, un git o el intérprete de otro programa que reescriban
# el enforcement (SC-sdk-setup-10). Se reconoce el repo por la identidad de cada carpeta (-ef), no
# por el texto: vale con carpetas enlazadas y con otras mayúsculas (macOS). Solo con builtins de
# bash, porque se usa antes de limpiar el PATH
under_repo() { # $1=ruta absoluta → 0 si ella o alguna carpeta por encima es el repo destino
  local d="$1"
  while :; do
    [ "$d" -ef "$TARGET" ] && return 0
    case "$d" in /|"") return 1 ;; esac
    d="${d%/*}"; [ -n "$d" ] || d=/
  done
}
# path_entry_bad <entrada del PATH> → vacía (la carpeta actual), relativa o que se alcanza desde
# el repo, por su ruta escrita o por la real
path_entry_bad() {
  local e="$1" pe
  case "$e" in /*) ;; *) return 0 ;; esac
  under_repo "$e" && return 0
  pe="$(cd -P "$e" 2>/dev/null && pwd -P)" && under_repo "$pe" && return 0
  return 1
}
# El PATH de setup, limpio antes de ejecutar nada: sin entradas vacías, relativas ni del repo
PATH_DROPPED=""; clean_path=""; rest="${PATH:-}:"
while [ -n "$rest" ]; do
  e="${rest%%:*}"; rest="${rest#*:}"
  if path_entry_bad "$e"; then PATH_DROPPED="$PATH_DROPPED «${e:-(vacía)}»"; continue; fi
  clean_path="${clean_path:+$clean_path:}$e"
done
PATH="$clean_path"; export PATH

[ -f "$SDK_ROOT/sentinel/hooks/sentinel-guard.sh" ] && [ -f "$SDK_ROOT/sentinel/policy.default.yaml" ] \
  && [ -f "$SDK_ROOT/ai-specs/skills/setup/chain.sh" ] && [ -f "$SDK_ROOT/.claude/settings.json" ] \
  || die "SDK incompleto en $SDK_ROOT: falta sentinel/, chain.sh o .claude/settings.json — ejecuta setup.sh desde una copia íntegra del SDK.
    Si lo ejecutas desde ~/.claude/skills/spec-sentinel-setup, comprueba que sea un enlace a la
    carpeta de la skill del SDK y no una copia (en Git Bash, ln -s copia: enlaza con
    MSYS=winsymlinks:nativestrict o con mklink /J, y compruébalo con test -L)"
# Con CRLF (un clon de Git for Windows sin el .gitattributes del SDK), bash no ejecuta los hooks:
# el Centinela lo denegaría todo y la Esclusa lo rechazaría todo (SC-sdk-setup-16)
CR="$(printf '\r')"
crlf="$( { dist_files; echo ai-specs/skills/setup/chain.sh; } | while IFS= read -r f; do
           LC_ALL=C grep -q "$CR" "$SDK_ROOT/$f" 2>/dev/null && printf ' %s' "$f"; done )"
[ -z "$crlf" ] || die "la copia del SDK tiene finales de línea CRLF en:$crlf.
    Con CRLF, bash no ejecuta los hooks. Vuelve a clonar el SDK (su .gitattributes lo evita) o,
    dentro de él y sin cambios locales (esto los descartaría), vuelve a sacar sus ficheros con LF:
    git rm -r -q --cached . && git reset -q --hard
    No se ha instalado nada"
# shellcheck source=chain.sh
source "$SDK_ROOT/ai-specs/skills/setup/chain.sh"
TOP="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" \
  || die "$TARGET no es un repo git — inicialízalo (git init) y vuelve a ejecutar setup"
# Solo en la raíz: dentro de un subdirectorio, la instalación caería en otro sitio (o en un repo padre)
if [ "$(cd "$TOP" && pwd -P)" != "$TARGET" ]; then
  [ ! "$TOP" -ef "${HOME:-/nonexistent}" ] || die "$TARGET no tiene git propio: el repo que lo
    contiene es tu carpeta personal ($TOP). Inicializa el proyecto con «git init» en $TARGET y
    vuelve a ejecutar setup ahí (SC-sdk-setup-18)"
  die "$TARGET no es la raíz del repo — ejecuta setup en $TOP"
fi
# La carpeta personal no es un proyecto: su .claude/ es la configuración de usuario de Claude
# Code, y el cableado fallaría en todos los demás proyectos (SC-sdk-setup-18)
if [ "$TARGET" -ef "${HOME:-/nonexistent}" ] || [ "$TARGET/.claude" -ef "${CLAUDE_CONFIG_DIR:-${HOME:-/nonexistent}/.claude}" ]; then
  die "$TARGET es tu carpeta personal, o su .claude/ es tu configuración de usuario de Claude
    Code: el cableado del Centinela acabaría ahí y fallaría en todos tus demás proyectos. Instala
    en la carpeta de cada proyecto, con su propio git. No se ha instalado nada"
fi
SELF=0; [ "$TARGET" = "$SDK_ROOT" ] && SELF=1

echo "Instalando el nivel Guardia en $TARGET"
[ -z "$PATH_DROPPED" ] || note "se quitan del PATH de setup las entradas vacías, relativas o que
    están dentro del repo destino (también a través de un enlace):$PATH_DROPPED. setup no ejecuta
    nada que venga del repo, y el cableado del Centinela tampoco: no usa el PATH de la sesión"

# Además del PATH limpio, los programas que se eligen por variable (SENTINEL_SETUP_JQ,
# SENTINEL_OPENSPEC_BIN) tampoco pueden venir del repo, se llegue a ellos como se llegue: ni la
# ruta por la que se encuentran, ni su carpeta real, ni ningún salto de su enlace
in_repo_bin() { # $1=ruta de un programa → 0 si se alcanza desde el repo
  local p="$1" d lnk hops=0 pd
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  while :; do
    pd="${p%/*}"; [ -n "$pd" ] || pd=/
    under_repo "$pd" && return 0
    d="$(cd "$pd" 2>/dev/null && pwd -P)" || return 0
    under_repo "$d" && return 0
    [ -L "$p" ] || return 1
    [ "$hops" -lt 40 ] || return 0
    lnk="$(readlink "$p")"
    case "$lnk" in /*) p="$lnk" ;; *) p="$d/$lnk" ;; esac
    hops=$((hops + 1))
  done
}
pick_bin() { # $1=nombre $2..=candidatos → PICKED, el primero que existe y no se alcanza desde el repo
  local what="$1" cand; shift
  for cand in "$@"; do
    cand="$(command -v "$cand" 2>/dev/null)" && [ -n "$cand" ] || continue
    if in_repo_bin "$cand"; then
      note "se ignora el $what de $cand: está dentro del repo destino o se llega a él desde dentro"
      PICK_SKIPPED=1; continue
    fi
    PICKED="$cand"; return 0
  done
  return 1
}
# resolve_bin <nombre> <explícito o vacío> → PICKED: el explícito o, si no se puede usar por
# alcanzarse desde el repo, el primero del PATH que valga. PICK_SKIPPED=1 si descartó alguno
resolve_bin() {
  local name="$1" explicit="$2" path_list rc
  PICKED=""; PICK_SKIPPED=0
  if [ -n "$explicit" ]; then
    pick_bin "$name" "$explicit" && return 0
    [ "$PICK_SKIPPED" -eq 1 ] || return 1
  fi
  path_list="$(type -aP "$name" 2>/dev/null)"
  local IFS=$'\n'; set -f
  pick_bin "$name" $path_list; rc=$?
  set +f; return $rc
}
resolve_bin jq "${SENTINEL_SETUP_JQ:-}"; JQ_BIN="$PICKED"
jq_why=""
if [ -n "${SENTINEL_SETUP_JQ:-}" ]; then
  if [ "$PICK_SKIPPED" -eq 1 ]; then jq_why="; el de SENTINEL_SETUP_JQ ($SENTINEL_SETUP_JQ) se alcanza desde el repo y no se usa"
  else jq_why="; el de SENTINEL_SETUP_JQ ($SENTINEL_SETUP_JQ) no existe"; fi
fi
[ -n "$JQ_BIN" ] || die "setup necesita jq (fuera del repo destino) para cablear el Centinela en .claude/settings.json${jq_why}.
    macOS: brew install jq · Windows: scoop install jq · Linux: apt install jq o dnf install jq
    (comprueba con: jq --version) y vuelve a ejecutar setup. No se ha instalado nada"
# jq lee ~/.jq en cada programa: con un HOME vacío, la configuración de la persona (que el agente
# podría escribir) no cambia lo que hacen los programas de setup (SC-sdk-setup-10)
JQ_HOME="$(mktemp -d 2>/dev/null)" && [ -d "$JQ_HOME" ] || die "no se pudo crear una carpeta temporal para ejecutar jq"
trap 'rm -rf "$JQ_HOME"' EXIT
jqx() { HOME="$JQ_HOME" "$JQ_BIN" "$@"; }
note "jq: $JQ_BIN ($(jqx --version 2>/dev/null | tr -d '\r' || echo 'versión desconocida'))"
# El fragmento es el cableado del propio SDK (su .claude/settings.json, que solo tiene «hooks»):
# una sola fuente, así un cambio de matcher llega a los consumidores al actualizar
FRAGMENT="$(cat "$SDK_ROOT/.claude/settings.json")"
jqx -e '(.hooks | type == "object" and length > 0) and all(.hooks[]; type == "array")' \
  "$SDK_ROOT/.claude/settings.json" >/dev/null 2>&1 \
  || die "el .claude/settings.json del SDK no es un cableado válido — ejecuta setup.sh desde una copia íntegra del SDK"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
backup() {
  local rel="$1" dir="$TARGET/sentinel/.backup/$STAMP"
  mkdir -p "$dir/$(dirname "$rel")" && cp -p "$TARGET/$rel" "$dir/$rel" \
    || die "no se pudo hacer backup de $rel — no se toca nada más"
  note "backup de $rel en sentinel/.backup/$STAMP/"
}

# ── 1. Enforcement distribuido (se actualiza) ────────────────────────────────────────────
if [ "$SELF" -eq 1 ]; then
  note "instalación sobre el propio SDK: el enforcement ya está en su sitio, no se copia"
else
  updated=0
  while IFS= read -r rel; do
    src="$SDK_ROOT/$rel"; dst="$TARGET/$rel"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
      [ -x "$src" ] && [ ! -x "$dst" ] && { chmod +x "$dst"; updated=$((updated + 1)); }
      continue
    fi
    [ -f "$dst" ] && backup "$rel"
    mkdir -p "$(dirname "$dst")" && cp "$src" "$dst" || die "no se pudo copiar $rel"
    [ -x "$src" ] && chmod +x "$dst"
    updated=$((updated + 1))
  done < <(dist_files)
  [ "$updated" -gt 0 ] && ok "enforcement instalado o actualizado ($updated ficheros en sentinel/)" \
    || ok "enforcement al día"
fi

# ── 2. Lo del consumidor (solo se crea si falta) ─────────────────────────────────────────
# La política del consumidor solo AÑADE reglas: las del SDK (policy.default.yaml) se evalúan
# antes y no se sustituyen (SC-sentinel-guard-17..19, SC-sdk-setup-05). Nivel Método (sdd: true)
# solo si el repo ya trabaja con OpenSpec.
CP="$TARGET/sentinel/policy.yaml"
policy_ids() { sed -nE 's/^[[:space:]]*-[[:space:]]+id:[[:space:]]*([^[:space:]]+).*/\1/p' "$1" | LC_ALL=C sort -u; }
dup=""
if [ -f "$CP" ]; then
  ok "política del consumidor conservada (sentinel/policy.yaml)"
  # Una política anterior a la separación repite las reglas del SDK: el Centinela la rechazaría
  dup="$(LC_ALL=C comm -12 <(policy_ids "$CP") <(policy_ids "$SDK_ROOT/sentinel/policy.default.yaml") | tr '\n' ' ')"
  [ -z "$dup" ] || todo "sentinel/policy.yaml repite reglas del SDK (${dup% }): ahora viven en
    sentinel/policy.default.yaml y el Centinela rechaza los ids duplicados. Deja en policy.yaml
    solo tus reglas propias (es un fichero protegido: lo edita una persona)"
else
  sdd=false; [ -d "$TARGET/openspec" ] && sdd=true
  cat >"$CP" <<EOF || die "no se pudo crear la política del consumidor"
# sentinel/policy.yaml — la política de ESTE proyecto (puesto Centinela).
# Las reglas del SDK viven en sentinel/policy.default.yaml y setup las actualiza. Aquí solo se
# AÑADEN reglas propias (mismo esquema): entre las dos políticas gana la decisión más estricta,
# y un id del SDK repetido es un error de política. Fichero protegido: se cambia en un cambio
# revisado por una persona.
version: 1
sdd: $sdd

rules:
EOF
  ok "política del consumidor creada (sentinel/policy.yaml, sdd: $sdd) — sin reglas propias aún"
fi
[ -f "$TARGET/sentinel/overrides.log" ] || { : >"$TARGET/sentinel/overrides.log" && ok "bitácora creada (sentinel/overrides.log)"; }

# .gitignore: la llave nunca se versiona; los backups tampoco; ni la configuración personal de
# Claude Code, que git deja de excluir si no lee el ignore global donde la pone Claude Code
# (p. ej. con un core.excludesFile propio) (SC-sdk-setup-15)
# add_lines <fichero relativo> <línea>… → añade las que falten (backup si el fichero ya existía)
add_lines() {
  local rel="$1" f="$TARGET/$1" line added=""; shift
  for line in "$@"; do
    # Sin el \r final: en un clon de Git for Windows las líneas llegan con CRLF (SC-sdk-setup-16)
    [ -f "$f" ] && tr -d '\r' <"$f" | grep -qxF -- "$line" && continue
    [ -f "$f" ] && [ -z "$added" ] && backup "$rel"
    [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ] && echo >>"$f"
    echo "$line" >>"$f"; added="$added $line"
  done
  [ -z "$added" ] || ok "$rel:$added"
}
add_lines .gitignore "sentinel/.override" "sentinel/.backup/" ".claude/settings.local.json"
# .gitattributes: sentinel/ siempre con LF, también en un clon de Git for Windows con
# core.autocrlf=true, donde bash no ejecutaría los hooks (SC-sdk-setup-16)
add_lines .gitattributes "sentinel/** text eol=lf"

# ── 3. Cableado del Centinela en .claude/settings.json ───────────────────────────────────
SCRIPTS='["sentinel/hooks/sentinel-guard.sh","sentinel/hooks/post-edit.sh","sentinel/hooks/session-start.sh"]'
# Fusión segura solo si cada evento es una lista de grupos y cada grupo una lista de hooks
SAFE='type == "object" and ((.hooks // {}) | type == "object")
      and ([ (.hooks // {})[] | type == "array" and all(.[]; type == "object"
               and ((.hooks // []) | type == "array") and all((.hooks // [])[]; type == "object")) ] | all)'
# Las entradas del SDK se reconocen por la ruta de su script (de cualquier versión, con o sin
# comillas): se quitan donde estén, sin tocar los hooks del consumidor de su mismo grupo, y se
# añaden las actuales al final de cada evento
SDK_DEFS='def is_sdk($s): (.command // "") as $c
            | ($c | type) == "string" and ([ $s[] as $x | $c | contains($x) ] | any);
          def strip_sdk($s):
            [ .[] | ((.hooks // []) | length) as $n
                  | ([ (.hooks // [])[] | select(is_sdk($s) | not) ]) as $k
                  | if $n == ($k | length) then . elif ($k | length) == 0 then empty else .hooks = $k end ];'
MERGE="$SDK_DEFS"'
       .hooks = ((.hooks // {}) | with_entries(.value |= strip_sdk($scripts)))
       | reduce ($frag.hooks | to_entries[]) as $e (.; .hooks[$e.key] = ((.hooks[$e.key] // []) + $e.value))'
# Lo que la fusión puede cambiar: solo las entradas del SDK. Fuera de «hooks», nada (un «env» con
# SENTINEL_* llega al Centinela, un disableAllHooks lo apaga); dentro, lo del consumidor tal cual
SAME="$SDK_DEFS"'
       def mine: (.hooks // {}) | with_entries(.value |= strip_sdk($sdk) | select(.value != []));
       (.[0] | del(.hooks)) == (.[1] | del(.hooks)) and (.[0] | mine) == (.[1] | mine)'
# El cableado del SDK está si cada grupo de cada evento del fragmento está, tal cual, en su
# evento (los eventos salen del fragmento); con otra forma, jq falla y no cuenta
WIRED='(.hooks // {}) as $h | ($h | type == "object")
       and all($frag.hooks | to_entries[]; .key as $k | ($h[$k] // []) as $have
               | ($have | type == "array") and all(.value[]; . as $g | any($have[]; . == $g)))'
# JSON_LEX: lo que jq acepta y JSON no. Fuera de las cadenas, solo los tokens de JSON (jq acepta
# NaN, Infinity, números como 01, +1, .5 o 5., la marca BOM); dentro, ningún byte de control
# (algunos jq lo aceptan). Claude Code, que lee con JSON.parse, descarta el fichero entero con
# cualquiera de ellos. La gramática la valida jq. Va por líneas porque, en lo que jq acepta, una
# cadena no cruza líneas; si encuentra algo, imprime la línea y qué es (SC-sdk-setup-10)
JSON_LEX='
function bad(what) { printf "en la línea %d, %s", NR, what; failed = 1; exit }
{
  s = $0; out = ""; instr = 0; esc = 0; n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (instr) {
      if (c < " ") bad("un byte de control dentro de una cadena")
      if (esc) esc = 0; else if (c == "\\") esc = 1; else if (c == "\"") { instr = 0; out = out "\"\"" }
      continue
    }
    if (c == "\"") { instr = 1; continue }
    out = out c
  }
  gsub(/[{}:,]/, " ", out); gsub(/\[/, " ", out); gsub(/\]/, " ", out)
  nt = split(out, t, /[ \t\r]+/)
  for (k = 1; k <= nt; k++)
    if (t[k] != "" && t[k] != "\"\"" && t[k] != "true" && t[k] != "false" && t[k] != "null" \
        && t[k] !~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$/) {
      if (NR == 1 && substr(t[k], 1, 3) == "\357\273\277") bad("una marca BOM al principio")
      bad("«" t[k] "», que JSON no admite (NaN, Infinity o un número como 01, +1, .5 o 5.)")
    }
}
END { exit failed }'

# json_ok <fichero> → es un objeto JSON que Claude Code puede cargar: sin bytes NUL, jq lo lee entero
# como un solo objeto (de una clave repetida vale la última, como en JSON.parse) y no hay nada que
# jq acepte y JSON no. Si no, JSON_ERR dice por qué y dónde
json_ok() {
  local where
  JSON_ERR=""
  if [ "$(LC_ALL=C tr -d '\000' <"$1" | wc -c)" -ne "$(wc -c <"$1")" ]; then
    JSON_ERR="tiene bytes NUL"; return 1
  fi
  if ! JSON_ERR="$(jqx -e -s 'length == 1 and (.[0] | type == "object")' "$1" 2>&1 >/dev/null)"; then
    JSON_ERR="$(printf '%s' "$JSON_ERR" | tr -d '\r')"
    [ -n "$JSON_ERR" ] || JSON_ERR="no es un único objeto JSON"
    return 1
  fi
  where="$(LC_ALL=C awk "$JSON_LEX" "$1")" && return 0
  JSON_ERR="tiene algo que jq acepta y JSON no: ${where:-sin detalle}"
  return 1
}
wired_ok() { jqx -e --argjson frag "$FRAGMENT" "$WIRED" "$1" >/dev/null 2>&1; }
# merged_ok <json> → el resultado de la fusión se puede escribir: Claude Code lo carga, conserva el
# cableado y solo cambia las entradas del SDK. Si no, MERGE_ERR dice qué falla. Lo comprueba el
# mismo jq que fusionó: un jq manipulado para falsearlo todo es el límite «jq manipulado»
merged_ok() {
  local t rc=1
  t="$(mktemp)" || return 1
  printf '%s\n' "$1" >"$t"
  if ! json_ok "$t"; then MERGE_ERR="no es JSON válido ($JSON_ERR)"
  elif ! wired_ok "$t"; then MERGE_ERR="no conserva el cableado del Centinela"
  elif ! jqx -e -s --argjson sdk "$SCRIPTS" "$SAME" "$S" "$t" >/dev/null 2>&1; then
    MERGE_ERR="cambia algo más que las entradas del SDK (fuera de «hooks» o hooks tuyos)"
  else rc=0; fi
  rm -f "$t"; return $rc
}

S="$TARGET/.claude/settings.json"; F="$TARGET/sentinel/settings.fragment.json"
write_fragment() { # $1=motivo [$2=qué hacer con el fragmento]
  [ -f "$F" ] && [ "$(cat "$F")" = "$FRAGMENT" ] || printf '%s\n' "$FRAGMENT" >"$F"
  todo "$1 — .claude/settings.json no se ha tocado. ${2:-Añade a mano los grupos de
    sentinel/settings.fragment.json, cada uno en su evento de «hooks» (sin repetir la clave de un
    evento que ya exista)} y vuelve a ejecutar setup"
}
# El paso manual ya está hecho: el fragmento sobra (y no debe acabar versionado)
drop_fragment() { [ -f "$F" ] && rm -f "$F" && note "retirado sentinel/settings.fragment.json: el cableado ya está"; return 0; }

S_OK=1
if [ ! -f "$S" ]; then
  mkdir -p "$TARGET/.claude" && printf '%s\n' "$FRAGMENT" >"$S" || die "no se pudo crear .claude/settings.json"
  ok "Centinela cableado (.claude/settings.json creado)"; drop_fragment
elif ! json_ok "$S"; then
  S_OK=0
  todo ".claude/settings.json no es JSON válido: $JSON_ERR.
    Claude Code no carga un fichero así, tampoco el Centinela, y setup no lo toca. Corrígelo y
    vuelve a ejecutar setup"
elif ! jqx -e "$SAFE" "$S" >/dev/null 2>&1; then
  # Se nombra lo que hay que corregir: una vez corregido, la siguiente ejecución fusiona
  # (proponer añadir los grupos a mano llevaba a un bucle: SAFE se mira antes que el cableado)
  bad_events="$(jqx -r '(.hooks // {}) | if type != "object" then "«hooks»" else
      [ to_entries[] | select((.value | type == "array" and all(.[]; type == "object"
          and ((.hooks // []) | type == "array") and all((.hooks // [])[]; type == "object"))) | not)
        | "«\(.key)»" ] | join(", ") end' "$S" 2>/dev/null | tr -d '\r')"
  todo ".claude/settings.json tiene una forma inesperada en ${bad_events:-«hooks»}: cada evento de
    «hooks» es una lista de grupos, y cada grupo lleva su lista «hooks» de objetos. setup no fusiona
    sobre esa forma y no ha tocado el fichero. Corrígela y vuelve a ejecutar setup: entonces añade
    el cableado del Centinela"
elif ! merged="$(jqx --argjson frag "$FRAGMENT" --argjson scripts "$SCRIPTS" "$MERGE" "$S" 2>/dev/null)"; then
  write_fragment "jq no pudo fusionar .claude/settings.json"
elif ! merged_ok "$merged"; then
  write_fragment "el resultado de la fusión $MERGE_ERR: no se escribe"
else
  if [ "$(jqx -S . "$S")" = "$(printf '%s' "$merged" | jqx -S .)" ]; then
    ok "Centinela ya cableado en .claude/settings.json"; drop_fragment
  else
    backup ".claude/settings.json"
    printf '%s\n' "$merged" >"$S" || die "no se pudo escribir .claude/settings.json"
    ok "Centinela cableado en .claude/settings.json: entradas del SDK al día, lo tuyo se conserva"
    drop_fragment
  fi
fi

# Cableado no es lo mismo que efectivo (SC-sdk-setup-14): con disableAllHooks, Claude Code no
# ejecuta ningún hook, y las variables de «env» llegan al proceso del Centinela. Se mira donde
# Claude Code lo lee: el proyecto, el local, la configuración de usuario y la gestionada. Se
# decide con el código de salida de jq, no comparando su texto (el jq.exe de Windows escribe CRLF)
check_effective() { # $1=fichero $2=cómo nombrarlo [$3=managed: la configuración gestionada]
  local f="$1" name="$2" kind="${3:-}" v keys envpath rest e bad_path=""
  local fixer="Quítalo (o ponlo a false) y vuelve a ejecutar setup"
  local fix_file="Corrígelo y vuelve a ejecutar setup" fix_env="Quítalas y vuelve a ejecutar setup"
  [ -f "$f" ] || return 0
  if [ "$kind" = managed ]; then
    fixer="Lo cambia quien administra la configuración gestionada de tu organización"
    fix_file="$fixer"; fix_env="$fixer"
  fi
  if [ ! -r "$f" ]; then
    todo "$name no se puede leer: no se puede comprobar si apaga los hooks (disableAllHooks) o le
    cambia la política al Centinela (su «env»). $fix_file"
    return 0
  fi
  if ! json_ok "$f"; then
    todo "$name no es JSON válido ($JSON_ERR): no se puede comprobar si apaga los hooks
    (disableAllHooks) o le cambia la política al Centinela (su «env»). $fix_file"
    return 0
  fi
  if jqx -e 'has("disableAllHooks") and .disableAllHooks != false' "$f" >/dev/null 2>&1; then
    v="$(jqx -c '.disableAllHooks' "$f" 2>/dev/null | tr -d '\r')"
    if [ "$v" = true ]; then
      todo "$name tiene «\"disableAllHooks\": true»: Claude Code no ejecuta ningún hook, tampoco
    el Centinela. $fixer"
    else
      todo "$name tiene «\"disableAllHooks\": ${v}», que no es un booleano: Claude Code puede no
    cargar el fichero entero, tampoco el Centinela. $fixer"
    fi
  fi
  if [ "$kind" = managed ] && jqx -e '.allowManagedHooksOnly == true' "$f" >/dev/null 2>&1; then
    todo "$name tiene «\"allowManagedHooksOnly\": true»: Claude Code solo ejecuta los hooks
    gestionados, no los del proyecto, así que el Centinela no actúa. $fixer"
  fi
  # Las variables de «env» llegan al proceso del Centinela y a la shell del agente: las que
  # cambian su política o su llave, cómo arranca bash o qué ejecuta, y la configuración de git
  # (que puede apagar core.hooksPath, es decir, la Esclusa)
  keys="$(jqx -r '.env | objects | keys[]
      | select(startswith("SENTINEL_") or startswith("GIT_CONFIG") or startswith("DYLD_")
               or startswith("BASH_FUNC_") or . == "BASH_ENV" or . == "SHELLOPTS" or . == "BASHOPTS"
               or . == "CLAUDE_PROJECT_DIR" or . == "GIT_DIR" or . == "GIT_COMMON_DIR"
               or . == "GIT_WORK_TREE" or . == "GIT_EXEC_PATH" or . == "LD_PRELOAD"
               or . == "LD_LIBRARY_PATH" or . == "GREP_OPTIONS")' \
      "$f" 2>/dev/null | tr -d '\r' | tr '\n' ' ')"
  [ -z "$keys" ] || todo "$name fija ${keys% } en «env»: Claude Code pasa esas variables al
    proceso del Centinela, que cambia de política, de llave o de código sin aviso, o a git, que
    puede dejar sin efecto la Esclusa. $fix_env"
  # PATH: con rutas absolutas de fuera del repo es lo normal; una entrada relativa (o vacía, que
  # es la carpeta actual) o dentro del repo haría que el Centinela ejecutara un bash del repo
  # Un PATH vacío también cuenta: es la carpeta actual, la raíz del proyecto (SC-sdk-setup-14)
  if jqx -e '.env | objects | has("PATH")' "$f" >/dev/null 2>&1; then
    envpath="$(jqx -r '.env.PATH | if type == "string" then . else "" end' "$f" 2>/dev/null | tr -d '\r')"
    rest="$envpath:"
    while [ -n "$rest" ]; do
      e="${rest%%:*}"; rest="${rest#*:}"
      path_entry_bad "$e" && bad_path="$bad_path «${e:-(vacía)}»"
    done
  fi
  [ -z "$bad_path" ] || todo "$name fija PATH en «env» con entradas vacías, relativas o que se
    alcanzan desde el repo (${bad_path# }): el Centinela podría ejecutar un bash o un git del repo,
    o ninguno. Usa rutas absolutas de fuera del repo. $fix_env"
}
[ "$S_OK" -eq 0 ] || check_effective "$S" ".claude/settings.json"
check_effective "$TARGET/.claude/settings.local.json" ".claude/settings.local.json"
UC="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}/settings.json"
check_effective "$UC" "$UC (tu configuración de usuario de Claude Code)"
case "$(uname -s 2>/dev/null)" in
  Darwin) managed_default="/Library/Application Support/ClaudeCode/managed-settings.json" ;;
  MINGW*|MSYS*|CYGWIN*) managed_default="/c/Program Files/ClaudeCode/managed-settings.json" ;;
  *) managed_default="/etc/claude-code/managed-settings.json" ;;
esac
MANAGED="${SENTINEL_SETUP_MANAGED:-$managed_default}"
check_effective "$MANAGED" "$MANAGED (configuración gestionada de tu organización)" managed

# ── 4. La Esclusa: core.hooksPath, o encadenada en los git hooks que ya hay ──────────────
# abs_dir <dir> → <dir> absoluto; uno relativo se resuelve, como hace git, desde la raíz del repo
abs_dir() { case "$1" in /*) printf '%s' "${1%/}" ;; *) printf '%s' "$TARGET/${1%/}" ;; esac; }
# own_hooks <dir> → « hook1 hook2…» ejecutables de <dir> (los .sample no cuentan)
own_hooks() {
  local d h list=""
  d="$(abs_dir "$1")"
  for h in "$d"/*; do
    [ -f "$h" ] && [ -x "$h" ] && case "$h" in *.sample) ;; *) list="$list $(basename "$h")" ;; esac
  done
  printf '%s' "$list"
}
# is_esclusa <hooksPath> → apunta a la Esclusa de este repo, se escriba como se escriba: se
# compara el directorio físico (relativo a la raíz, absoluto, con ./, barra final o enlaces)
is_esclusa() {
  local d
  d="$(abs_dir "$1")"
  [ -d "$d" ] && [ -d "$TARGET/$HOOKS_PATH" ] \
    && [ "$(cd "$d" && pwd -P)" = "$(cd "$TARGET/$HOOKS_PATH" && pwd -P)" ]
}
# chain_todo <situación> <dir de los hooks> → pendiente con las líneas de chain.sh para cada hook
chain_todo() {
  local h lines=""
  for h in commit-msg pre-commit pre-push; do
    lines="$lines
    ── $2/$h (créalo ejecutable si no existe):
$(chain_snippet "$h" | sed 's/^/      /')"
  done
  todo "$1
    Encadena la Esclusa: pon estas líneas al principio de cada hook (tras el shebang). Así un
    exit del hook no se las salta, el resto del pre-push sigue recibiendo las refs y, en un repo
    sin la Esclusa, no hacen nada. Después vuelve a ejecutar setup.$lines"
}

cur="$(git -C "$TARGET" config --get core.hooksPath || true)"
# El valor tal cual y expandido como lo hace git (~, rutas): los dos sirven para reconocerla
cur_dir="$(git -C "$TARGET" config --type=path --get core.hooksPath 2>/dev/null || printf '%s' "$cur")"
cur_dir="${cur_dir%/}"
if [ -n "$cur" ] && { is_esclusa "$cur" || is_esclusa "$cur_dir"; }; then
  ok "Esclusa activa (core.hooksPath → $cur)"
elif [ -n "$cur" ]; then
  # Puede venir del config global de la persona (p. ej. un escáner corporativo): tampoco se pisa
  origin="$(git -C "$TARGET" config --show-origin --get core.hooksPath 2>/dev/null | cut -f1)"
  scope=""
  [ -n "$(git -C "$TARGET" config --local --get core.hooksPath 2>/dev/null)" ] \
    || scope=" Ese core.hooksPath no es de este repo: vale para todos tus repos."
  case "$cur_dir" in
    .husky/_|*/.husky/_)
      # husky v9: .husky/_ son envoltorios generados (e ignorados por git) que ejecutan .husky/<hook>
      hsrc="${cur_dir%/_}"
      if chain_done "$(abs_dir "$hsrc")"; then
        ok "Esclusa encadenada en husky ($hsrc/commit-msg, pre-commit y pre-push)"
      else
        chain_todo "el repo usa husky (core.hooksPath → «${cur}»). Los envoltorios de «${cur}» los
    genera husky y git los ignora: los hooks están en $hsrc/<hook>, y ahí va la Esclusa. setup
    no cambia core.hooksPath." "$hsrc"
      fi ;;
    *)
      if [ -z "$(own_hooks "$cur_dir")" ]; then
        # Un hooksPath global y relativo (p. ej. «.githooks») sin esa carpeta aquí no ejecuta nada
        todo "core.hooksPath → «${cur}» (definido en ${origin:-config de git}) no tiene hooks en este repo:
    hoy no ejecuta nada aquí, así que activar la Esclusa no silencia nada. setup no cambia
    configuración de git que no es suya; actívala tú (solo afecta a este repo):
    git config core.hooksPath $HOOKS_PATH"
      elif chain_done "$(abs_dir "$cur_dir")" exec; then
        ok "Esclusa encadenada en los hooks de «${cur}»"
      elif git -C "$TARGET" check-ignore -q -- "$cur_dir/pre-commit" 2>/dev/null; then
        chain_todo "core.hooksPath → «${cur}» está ignorado por git: lo genera una herramienta y lo que
    pongas ahí se perderá. Pon las líneas en los hooks fuente de esa herramienta, no en «${cur}»." "<hooks fuente>"
      else
        chain_todo "el repo ya usa core.hooksPath → «${cur}» (definido en ${origin:-config de git}); no se
    cambia para no silenciar esos hooks.${scope} Si en este repo no los necesitas, la
    alternativa es activar la Esclusa solo aquí: git config core.hooksPath $HOOKS_PATH" "$cur"
      fi ;;
  esac
else
  hd="$(git -C "$TARGET" rev-parse --git-path hooks)"
  own="$(own_hooks "$hd")"
  if [ -z "$own" ]; then
    git -C "$TARGET" config core.hooksPath "$HOOKS_PATH" || die "no se pudo configurar core.hooksPath"
    ok "Esclusa activada (core.hooksPath → $HOOKS_PATH)"
  elif chain_done "$(abs_dir "$hd")" exec; then
    ok "Esclusa encadenada en los hooks de $hd (core.hooksPath no se activa: los silenciaría)"
  else
    chain_todo "hay git hooks propios en $hd:$own. Activar core.hooksPath los dejaría sin
    ejecutarse, así que no se activa: la Esclusa se encadena en ellos, donde están." "$hd"
  fi
fi

# Lo comprobado hasta aquí (los settings de Claude Code y core.hooksPath) no puede cambiar en lo
# que queda: setup aún ejecuta programas (openspec, la prueba de humo del Centinela). Se toma una
# foto y al final se compara (SC-sdk-setup-10)
checked_snapshot() {
  local f rel
  for f in "$S" "$TARGET/.claude/settings.local.json" "$UC" "$MANAGED" "$CP" \
           "$TARGET/.gitignore" "$TARGET/.gitattributes"; do
    if [ -f "$f" ]; then cksum <"$f" 2>/dev/null || echo "?"; else echo "-"; fi
  done
  # El enforcement copiado en el paso 1 (A7-3)
  while IFS= read -r rel; do
    if [ -f "$TARGET/$rel" ]; then cksum <"$TARGET/$rel" 2>/dev/null || echo "?"; else echo "-"; fi
  done < <(dist_files)
  git -C "$TARGET" config --get core.hooksPath 2>/dev/null || echo "-"
}
CHECKED="$(checked_snapshot)"

# ── 5. Adaptador de stack: se propone, nunca se aplica solo ──────────────────────────────
A="$TARGET/sentinel/adapters"
if [ -f "$A/stack.yaml" ]; then
  ok "adaptador de stack declarado (sentinel/adapters/stack.yaml)"
else
  # shellcheck source=/dev/null
  source "$SDK_ROOT/sentinel/adapters/stack.sh"
  if proposal="$(stack_detect "$TARGET" 2>/dev/null)"; then
    if ! { [ -f "$A/stack.proposed.yaml" ] && [ "$(cat "$A/stack.proposed.yaml")" = "$proposal" ]; }; then
      # Una propuesta que la persona ya revisó no se pierde
      [ -f "$A/stack.proposed.yaml" ] && backup "sentinel/adapters/stack.proposed.yaml"
      printf '%s\n' "$proposal" >"$A/stack.proposed.yaml"
    fi
    note "stack detectado: propuesta en sentinel/adapters/stack.proposed.yaml. Revísala y
    renómbrala a stack.yaml para que la Esclusa ejecute format, lint y tests"
  else
    note "stack no reconocido (Node o Laravel): sin sentinel/adapters/stack.yaml la Esclusa omite
    format, lint y tests con aviso. Escríbelo a mano (formato en sentinel/adapters/stack.sh)"
  fi
fi

# ── 6. Herramientas obligatorias: se avisa ahora, no en el primer commit ─────────────────
if command -v "$GITLEAKS" >/dev/null 2>&1; then
  ok "gitleaks disponible"
else
  todo "gitleaks no está instalado y es obligatorio: la Esclusa rechazará todos los commits.
    macOS: brew install gitleaks · Windows: scoop install gitleaks · Linux: binario de
    https://github.com/gitleaks/gitleaks/releases (comprueba con: gitleaks version)"
fi
# Nivel Método (sdd: true): el pre-push exigirá openspec validate --strict. Si ya falla, el primer
# push se rechazaría por sorpresa: se dice ahora y cómo desactivarlo (SC-sdk-setup-17). El
# openspec, con la misma regla que jq: nunca uno al que se llega desde el repo (SC-sdk-setup-10)
if [ -d "$TARGET/openspec" ] && grep -qE '^[[:space:]]*sdd:[[:space:]]*true' "$CP" 2>/dev/null; then
  resolve_bin openspec "${SENTINEL_OPENSPEC_BIN:-}"; OPENSPEC="$PICKED"
  if [ -z "$OPENSPEC" ] && [ "$PICK_SKIPPED" -eq 1 ]; then
    note "sentinel/policy.yaml tiene sdd: true (nivel Método); el único openspec disponible se
    alcanza desde el repo y setup no lo ejecuta: se omite la comprobación de specs"
  elif [ -z "$OPENSPEC" ]; then
    note "sentinel/policy.yaml tiene sdd: true (nivel Método), pero el CLI de OpenSpec no está
    instalado: la Esclusa omitirá con aviso la validación de specs en cada push"
  elif ! os_out="$(cd "$TARGET" && "$OPENSPEC" validate --all --strict 2>&1)"; then
    todo "sentinel/policy.yaml tiene sdd: true (nivel Método) y openspec validate --all --strict falla:
$(printf '%s\n' "$os_out" | tr -d '\r' | tail -n 12 | sed 's/^/      /')
    El pre-push de la Esclusa exige esa validación, así que el push se rechazaría. Corrige los
    cambios de openspec/ o, si este repo no quiere el nivel Método, pon sdd: false en
    sentinel/policy.yaml (fichero protegido: lo decide y lo edita una persona)"
  fi
fi

# ── 7. Lo que tiene que viajar con el repo no puede estar ignorado ───────────────────────
# Todo lo que se instala (no una muestra: la librería de la Esclusa también) y lo del consumidor
versioned() {
  dist_files
  printf '%s\n' sentinel/policy.yaml sentinel/overrides.log .claude/settings.json
  [ ! -f "$TARGET/sentinel/adapters/stack.yaml" ] || echo sentinel/adapters/stack.yaml
}
# exception_for <fichero> → las líneas que lo reincluyen desde el .gitignore del repo (que manda
# sobre core.excludesFile). Si se ignora una carpeta que lo contiene, git no mira dentro: hay que
# reincluir la carpeta. De .claude/ se reincluyen la carpeta y settings.json, sin volver a
# ignorar el resto: comandos, agentes y skills son del equipo, y lo personal
# (settings.local.json) ya lo excluye su propia línea del .gitignore (SC-sdk-setup-11, 15)
exception_for() {
  local f="$1" d top=""
  case "$f" in .claude/settings.json) printf '%s\n' '!.claude/' '!.claude/settings.json'; return 0 ;; esac
  d="$(dirname "$f")"
  while [ "$d" != "." ]; do
    git -C "$TARGET" check-ignore -q -- "$d/" 2>/dev/null && top="$d"
    d="$(dirname "$d")"
  done
  if [ -n "$top" ]; then printf '!%s/\n' "$top"; else printf '!%s\n' "$f"; fi
}
ignored=""; exceptions=""; nested=""
while IFS= read -r f; do
  # -q decide (una excepción «!…» también aparece en -v, pero no ignora); -v solo dice qué regla
  git -C "$TARGET" check-ignore -q -- "$f" 2>/dev/null || continue
  why="$(git -C "$TARGET" check-ignore -v -- "$f" 2>/dev/null | cut -f1)"
  src="${why%%:*}"; rest="${why#*:}"
  ignored="$ignored
      $f — lo ignora «${rest#*:}» ($src, línea ${rest%%:*})"
  # La regla está en el .gitignore de una subcarpeta del repo: la excepción va en ese fichero y
  # relativa a él; en el de la raíz no tendría efecto (SC-sdk-setup-11)
  case "$src" in
    /*|.gitignore) ;;
    */.gitignore) nested="$nested
$src|!${f#"${src%/.gitignore}"/}"; continue ;;
  esac
  exceptions="$exceptions
$(exception_for "$f")"
done < <(versioned)
if [ -n "$ignored" ]; then
  where=""
  if [ -n "$(printf '%s' "$exceptions" | tr -d '[:space:]')" ]; then
    where="
    Añade al final del .gitignore del repo (vale aunque la regla venga de fuera, p. ej. de
    core.excludesFile):
$(printf '%s\n' "$exceptions" | awk 'NF && !seen[$0]++' | sed 's/^/      /')"
  fi
  [ -z "$nested" ] || where="$where
$(printf '%s\n' "$nested" | awk -F'|' 'NF == 2 && !seen[$0]++ {
      if (!($1 in lines)) order[++n] = $1
      lines[$1] = lines[$1] "      " $2 "\n" }
    END { for (i = 1; i <= n; i++)
            printf "    Añade al final de %s (la regla está ahí: una excepción en otro .gitignore no la anula):\n%s", order[i], lines[order[i]] }')"
  todo "el .gitignore deja fuera ficheros que hay que versionar:$ignored
    Sin ellos en git, tus compañeros no reciben el Centinela o la Esclusa, o la bitácora se queda
    en tu máquina.$where
    Compruébalo con: git check-ignore -v <fichero>"
fi
# Y lo que no debe viajar: la llave, los backups y la configuración personal de Claude Code. Se
# comprueba con git, no buscando la línea (una regla posterior puede anularla), y lo que ya está
# versionado no lo saca el .gitignore del índice (SC-sdk-setup-15)
for f in sentinel/.override sentinel/.backup/ .claude/settings.local.json; do
  if git -C "$TARGET" ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
    case "$f" in */) rmcmd="git rm -r --cached $f" ;; *) rmcmd="git rm --cached $f" ;; esac
    todo "$f está versionado y no debe viajar con el repo: el .gitignore no lo saca del índice, así
    que sus cambios irían en tus commits. Sácalo (lo ejecutas tú; se queda en tu disco):
    $rmcmd"
  elif ! git -C "$TARGET" check-ignore -q --no-index -- "$f" 2>/dev/null; then
    todo "$f no está ignorado por git, aunque el .gitignore tiene su línea: una regla posterior la
    anula ($(git -C "$TARGET" check-ignore -v --no-index -n -- "$f" 2>/dev/null | cut -f1)). Quita esa regla y vuelve a ejecutar setup"
  fi
done
# Una llave que ya está al instalar (se pudo escribir cuando aún no había Centinela) deja pasar,
# y registra, la primera acción que el Centinela bloquee: la decide la persona (SC-sdk-setup-15)
[ ! -e "$TARGET/sentinel/.override" ] || todo "hay una llave sin usar (sentinel/.override): el Centinela
    dejará pasar, y registrará en la bitácora, la primera acción que bloquee, venga de quien venga.
    Si no la pusiste tú para algo concreto que aún no se ha hecho, bórrala (el agente no puede):
    rm sentinel/.override"
# El .gitattributes que pone sentinel/ en LF tiene que aplicarse (SC-sdk-setup-16)
[ "$(git -C "$TARGET" check-attr eol -- sentinel/hooks/sentinel-guard.sh 2>/dev/null | sed 's/.*: //')" = lf ] \
  || todo "el .gitattributes del repo no deja sentinel/ en LF (una regla posterior anula
    «sentinel/** text eol=lf»): en un clon de Git for Windows, bash no ejecutaría los hooks.
    Compruébalo con: git check-attr eol -- sentinel/hooks/sentinel-guard.sh"

# Con core.fileMode=false git no guarda el permiso de ejecución: en los clones ignoraría los hooks
if [ "$(git -C "$TARGET" config --bool core.fileMode 2>/dev/null)" = "false" ]; then
  noexec=""
  while IFS= read -r f; do
    [ -x "$SDK_ROOT/$f" ] || continue
    [ "$(git -C "$TARGET" ls-files -s -- "$f" | cut -d' ' -f1)" = 100755 ] || noexec="$noexec $f"
  done < <(dist_files)
  [ -z "$noexec" ] || todo "este repo tiene core.fileMode=false: git no guarda el permiso de ejecución
    y en los clones ignora los hooks que no lo tienen (la Esclusa no correría). Después del git
    add, márcalos como ejecutables en el índice:
    git add --chmod=+x$noexec"
fi

# ── 8. El Centinela instalado tiene que dejar pasar lo inocuo ────────────────────────────
# Una acción de shell, una lectura y una edición (las reglas de ruta solo se evalúan con su
# tool). Con ids duplicados ya hay un pendiente que explica el bloqueo. Se lanza con su
# cableado, tal como queda en .claude/settings.json y como lo lanza Claude Code: en esta máquina
# puede no encontrar git en su PATH fijo, y entonces bloquearía todo (revisión de sentinel-paths,
# P1)
if [ -z "$dup" ]; then
  smoke_path="$(printf '%s' "$TARGET/smoke-test.txt" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
  wiring="$(jqx -r '[.hooks.PreToolUse[]?.hooks[]?.command | select(contains("sentinel/hooks/sentinel-guard.sh"))][0] // empty' \
    "$SDK_ROOT/.claude/settings.json" 2>/dev/null)"
  while IFS='|' read -r what payload; do
    smoke_err="$(cd "$TARGET" && printf '%s' "$payload" \
      | env -u SENTINEL_POLICY -u SENTINEL_POLICY_DEFAULT -u SENTINEL_OVERRIDE -u SENTINEL_CONFIRM \
          CLAUDE_PROJECT_DIR="$TARGET" /bin/sh -c "$wiring" 2>&1 >/dev/null)" && continue
    case "$smoke_err" in
      sentinel-guard:*)
        todo "el Centinela instalado deniega una acción inocua ($what): ${smoke_err#sentinel-guard: }
    Mientras siga así, el agente no podrá trabajar en este repo. Revisa sentinel/policy.yaml" ;;
      *)
        todo "el cableado del Centinela (.claude/settings.json) no deja pasar una acción inocua ($what) en
    esta máquina: ${smoke_err:-sale con un código que no es una decisión}
    Mientras siga así, Claude Code bloqueará todas las acciones del agente en este repo" ;;
    esac
    break
  done <<EOF
\`true\` en shell|{"tool_name":"Bash","tool_input":{"command":"true"}}
leer un fichero|{"tool_name":"Read","tool_input":{"file_path":"$smoke_path"}}
editar un fichero|{"tool_name":"Edit","tool_input":{"file_path":"$smoke_path","old_string":"a","new_string":"b"}}
EOF
fi

[ "$(checked_snapshot)" = "$CHECKED" ] \
  || todo "los settings de Claude Code, core.hooksPath, el enforcement copiado, las políticas,
    .gitignore o .gitattributes cambiaron mientras se ejecutaba setup (lo hizo alguno de los
    programas que ejecuta después de comprobarlos): lo comprobado ya no vale. Revisa qué ha
    cambiado (git status) y vuelve a ejecutar setup"

echo
if [ "$pending" -eq 1 ]; then
  echo "Nivel Guardia instalado con pasos pendientes (⚠ arriba). Vuelve a ejecutar setup al resolverlos."
  exit 3
fi
echo "✓ Nivel Guardia instalado. Versiónalo en un commit, revisando antes git status: git add sentinel .claude .gitignore .gitattributes"
echo "  Comprueba en una sesión nueva de Claude Code, abierta en la raíz del repo, que /hooks muestra sentinel-guard."
exit 0
