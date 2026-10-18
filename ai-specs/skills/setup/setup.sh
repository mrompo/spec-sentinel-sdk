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
#     la fusión no es segura, se deja sentinel/settings.fragment.json y se explica el paso manual;
#   - core.hooksPath solo se activa si el repo no usa ya otros git hooks; si los usa, se dan
#     las líneas que encadenan la Esclusa en ellos (chain.sh) y se reconoce cuando ya están.
# Los backups van a sentinel/.backup/<fecha>/ (fuera de git).
#
# Salida: 0 instalado · 3 instalado con pasos pendientes (se listan) · 1 error. Si falla una
# comprobación previa no se escribe nada; si falla a mitad, lo hecho se queda y reejecutar es seguro.
# Variables: SENTINEL_SETUP_JQ (binario de jq), SENTINEL_GITLEAKS_BIN (el mismo que la Esclusa),
# CLAUDE_CONFIG_DIR (la configuración de usuario de Claude Code, como en Claude Code).
# Falsifica: SC-sdk-setup-01..15 (fixture/install/cases/).
set -uo pipefail

# cd -P primero: a través de un enlace a la skill (~/.claude/skills/spec-sentinel-setup) se sube
# desde la real
SDK_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd -P)"
GITLEAKS="${SENTINEL_GITLEAKS_BIN:-gitleaks}"
HOOKS_PATH="sentinel/githooks"

pending=0
die()  { echo "✗ [setup] $1" >&2; exit 1; }
ok()   { echo "✓ $1"; }
note() { echo "· $1"; }
todo() { echo "⚠ PENDIENTE: $1"; pending=1; }

# ── Comprobaciones: nada se escribe hasta que todo cuadra ────────────────────────────────
[ -f "$SDK_ROOT/sentinel/hooks/sentinel-guard.sh" ] && [ -f "$SDK_ROOT/sentinel/policy.default.yaml" ] \
  && [ -f "$SDK_ROOT/ai-specs/skills/setup/chain.sh" ] && [ -f "$SDK_ROOT/.claude/settings.json" ] \
  || die "SDK incompleto en $SDK_ROOT: falta sentinel/, chain.sh o .claude/settings.json — ejecuta setup.sh desde una copia íntegra del SDK"
# shellcheck source=chain.sh
source "$SDK_ROOT/ai-specs/skills/setup/chain.sh"
[ -d "${1:-.}" ] || die "no existe el directorio ${1:-.}"
TARGET="$(cd "${1:-.}" && pwd -P)"
TOP="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" \
  || die "$TARGET no es un repo git — inicialízalo (git init) y vuelve a ejecutar setup"
# Solo en la raíz: dentro de un subdirectorio, la instalación caería en otro sitio (o en un repo padre)
[ "$(cd "$TOP" && pwd -P)" = "$TARGET" ] \
  || die "$TARGET no es la raíz del repo — ejecuta setup en $TOP"
SELF=0; [ "$TARGET" = "$SDK_ROOT" ] && SELF=1

echo "Instalando el nivel Guardia en $TARGET"

# jq es obligatorio (SC-sdk-setup-04): con él se lee, se fusiona y se comprueba .claude/settings.json
# como lo carga Claude Code. Nunca uno que viva dentro del repo destino, tampoco a través de un
# enlace (el agente podría poner ahí uno que «fusione» quitando el cableado): el de
# SENTINEL_SETUP_JQ o, si no, el primero del PATH que esté fuera (SC-sdk-setup-10)
JQ_BIN=""
if [ -n "${SENTINEL_SETUP_JQ:-}" ]; then jq_cands="$SENTINEL_SETUP_JQ"; else jq_cands="$(type -aP jq 2>/dev/null)"; fi
while IFS= read -r cand; do
  cand="$(command -v "$cand" 2>/dev/null)" && [ -n "$cand" ] || continue
  real="$cand"; hops=0
  while [ -L "$real" ] && [ "$hops" -lt 40 ]; do
    lnk="$(readlink "$real")"
    case "$lnk" in /*) real="$lnk" ;; *) real="$(dirname "$real")/$lnk" ;; esac
    hops=$((hops + 1))
  done
  [ ! -L "$real" ] || continue
  jq_dir="$(cd "$(dirname "$real")" 2>/dev/null && pwd -P)" || continue
  case "$jq_dir/" in
    "$TARGET"/*) note "se ignora el jq de $cand: está dentro del repo destino"; continue ;;
  esac
  JQ_BIN="$cand"; break
done <<<"$jq_cands"
[ -n "$JQ_BIN" ] || die "setup necesita jq (fuera del repo destino) para cablear el Centinela en .claude/settings.json.
    macOS: brew install jq · Windows: scoop install jq · Linux: apt install jq o dnf install jq
    (comprueba con: jq --version) y vuelve a ejecutar setup. No se ha instalado nada"
note "jq: $JQ_BIN ($("$JQ_BIN" --version 2>/dev/null || echo 'versión desconocida'))"
# El fragmento es el cableado del propio SDK (su .claude/settings.json, que solo tiene «hooks»):
# una sola fuente, así un cambio de matcher llega a los consumidores al actualizar
FRAGMENT="$(cat "$SDK_ROOT/.claude/settings.json")"
"$JQ_BIN" -e '(.hooks | type == "object" and length > 0) and all(.hooks[]; type == "array")' \
  "$SDK_ROOT/.claude/settings.json" >/dev/null 2>&1 \
  || die "el .claude/settings.json del SDK no es un cableado válido — ejecuta setup.sh desde una copia íntegra del SDK"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
backup() {
  local rel="$1" dir="$TARGET/sentinel/.backup/$STAMP"
  mkdir -p "$dir/$(dirname "$rel")" && cp -p "$TARGET/$rel" "$dir/$rel" \
    || die "no se pudo hacer backup de $rel — no se toca nada más"
  note "backup de $rel en sentinel/.backup/$STAMP/"
}

# dist_files → lo que el SDK distribuye (rutas relativas): lo que se copia y lo que tiene que
# poder versionarse
dist_files() {
  (cd "$SDK_ROOT" && find sentinel/README.md sentinel/policy.default.yaml sentinel/hooks sentinel/githooks sentinel/adapters \
     -type f ! -name '.*' ! -name stack.yaml ! -name stack.proposed.yaml | LC_ALL=C sort)
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
GI="$TARGET/.gitignore"; gi_added=""
for line in "sentinel/.override" "sentinel/.backup/" ".claude/settings.local.json"; do
  [ -f "$GI" ] && grep -qxF "$line" "$GI" && continue
  [ -f "$GI" ] && [ -z "$gi_added" ] && backup ".gitignore"
  [ -s "$GI" ] && [ -n "$(tail -c1 "$GI")" ] && echo >>"$GI"
  echo "$line" >>"$GI"; gi_added="$gi_added $line"
done
[ -n "$gi_added" ] && ok ".gitignore:$gi_added"

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
# JSON_LEX: fuera de las cadenas, solo los tokens de JSON. jq acepta de más (NaN, Infinity, números
# como 01, +1, .5 o 5., la marca BOM) y Claude Code, que lee con JSON.parse, descarta el fichero
# entero con cualquiera de ellos. La gramática la valida jq; esto, solo los tokens. Va por líneas
# porque, en lo que jq acepta, una cadena no cruza líneas
JSON_LEX='
{
  s = $0; out = ""; instr = 0; esc = 0; n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (instr) { if (esc) esc = 0; else if (c == "\\") esc = 1; else if (c == "\"") { instr = 0; out = out "\"\"" }; continue }
    if (c == "\"") { instr = 1; continue }
    out = out c
  }
  gsub(/[{}:,]/, " ", out); gsub(/\[/, " ", out); gsub(/\]/, " ", out)
  nt = split(out, t, /[ \t\r]+/)
  for (k = 1; k <= nt; k++)
    if (t[k] != "" && t[k] != "\"\"" && t[k] != "true" && t[k] != "false" && t[k] != "null" \
        && t[k] !~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$/) { bad = 1; exit }
}
END { exit bad }'

# json_ok <fichero> → es un objeto JSON que Claude Code puede cargar: jq lo lee entero como un solo
# objeto (de una clave repetida vale la última, como en JSON.parse) y no hay nada que jq acepte y
# JSON no. Si no, JSON_ERR dice por qué (el error de jq dice dónde)
json_ok() {
  JSON_ERR=""
  if ! JSON_ERR="$("$JQ_BIN" -e -s 'length == 1 and (.[0] | type == "object")' "$1" 2>&1 >/dev/null)"; then
    [ -n "$JSON_ERR" ] || JSON_ERR="no es un único objeto JSON"
    return 1
  fi
  LC_ALL=C awk "$JSON_LEX" "$1" && return 0
  JSON_ERR="tiene algo que jq acepta y JSON no: NaN, Infinity, un número como 01, +1, .5 o 5., o una marca BOM al principio"
  return 1
}
wired_ok() { "$JQ_BIN" -e --argjson frag "$FRAGMENT" "$WIRED" "$1" >/dev/null 2>&1; }
# merged_ok <json> → el resultado de la fusión se puede escribir: Claude Code lo carga, conserva el
# cableado y solo cambia las entradas del SDK. Si no, MERGE_ERR dice qué falla. Lo comprueba el
# mismo jq que fusionó: un jq manipulado para falsearlo todo es el límite «jq manipulado»
merged_ok() {
  local t rc=1
  t="$(mktemp)" || return 1
  printf '%s\n' "$1" >"$t"
  if ! json_ok "$t"; then MERGE_ERR="no es JSON válido ($JSON_ERR)"
  elif ! wired_ok "$t"; then MERGE_ERR="no conserva el cableado del Centinela"
  elif ! "$JQ_BIN" -e -s --argjson sdk "$SCRIPTS" "$SAME" "$S" "$t" >/dev/null 2>&1; then
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
elif ! "$JQ_BIN" -e "$SAFE" "$S" >/dev/null 2>&1; then
  write_fragment ".claude/settings.json tiene una forma inesperada en «hooks» (cada evento, una lista de
    grupos; cada grupo, con su lista «hooks»): fusionar no es seguro" "Corrige esa forma, o añade a mano
    los grupos de sentinel/settings.fragment.json, cada uno en su evento de «hooks»,"
elif ! merged="$("$JQ_BIN" --argjson frag "$FRAGMENT" --argjson scripts "$SCRIPTS" "$MERGE" "$S" 2>/dev/null)"; then
  write_fragment "jq no pudo fusionar .claude/settings.json"
elif ! merged_ok "$merged"; then
  write_fragment "el resultado de la fusión $MERGE_ERR: no se escribe"
else
  if [ "$("$JQ_BIN" -S . "$S")" = "$(printf '%s' "$merged" | "$JQ_BIN" -S .)" ]; then
    ok "Centinela ya cableado en .claude/settings.json"; drop_fragment
  else
    backup ".claude/settings.json"
    printf '%s\n' "$merged" >"$S" || die "no se pudo escribir .claude/settings.json"
    ok "Centinela cableado en .claude/settings.json: entradas del SDK al día, lo tuyo se conserva"
    drop_fragment
  fi
fi

# Cableado no es lo mismo que efectivo (SC-sdk-setup-14): con disableAllHooks, Claude Code no
# ejecuta ningún hook, y las variables de «env» llegan al Centinela. Se mira en los tres sitios
# donde Claude Code lo lee: el proyecto, el local y la configuración de usuario
check_effective() { # $1=fichero $2=cómo nombrarlo
  local f="$1" name="$2" v keys
  [ -f "$f" ] || return 0
  if ! json_ok "$f"; then
    todo "$name no es JSON válido ($JSON_ERR): no se puede comprobar si apaga los hooks
    (disableAllHooks) o le cambia la política al Centinela (un «env» con SENTINEL_*). Corrígelo y
    vuelve a ejecutar setup"
    return 0
  fi
  v="$("$JQ_BIN" -c 'if has("disableAllHooks") then .disableAllHooks else empty end' "$f" 2>/dev/null)"
  case "$v" in
    ""|false) ;;
    true) todo "$name tiene «\"disableAllHooks\": true»: Claude Code no ejecuta ningún hook, tampoco
    el Centinela. Quítalo (o ponlo a false) y vuelve a ejecutar setup" ;;
    *) todo "$name tiene «\"disableAllHooks\": ${v}», que no es un booleano: Claude Code puede no cargar
    el fichero entero, tampoco el Centinela. Quítalo (o ponlo a false) y vuelve a ejecutar setup" ;;
  esac
  keys="$("$JQ_BIN" -r '.env | objects | keys[] | select(startswith("SENTINEL_"))' "$f" 2>/dev/null | tr '\n' ' ')"
  [ -z "$keys" ] || todo "$name fija ${keys% } en «env»: Claude Code pasa esas variables al
    Centinela, que cambia de política o de llave sin aviso. Quítalas y vuelve a ejecutar setup"
}
[ "$S_OK" -eq 0 ] || check_effective "$S" ".claude/settings.json"
check_effective "$TARGET/.claude/settings.local.json" ".claude/settings.local.json"
UC="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}/settings.json"
check_effective "$UC" "$UC (tu configuración de usuario de Claude Code)"

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

# ── 7. Lo que tiene que viajar con el repo no puede estar ignorado ───────────────────────
# Todo lo que se instala (no una muestra: la librería de la Esclusa también) y lo del consumidor
versioned() {
  dist_files
  printf '%s\n' sentinel/policy.yaml sentinel/overrides.log .claude/settings.json
  [ ! -f "$TARGET/sentinel/adapters/stack.yaml" ] || echo sentinel/adapters/stack.yaml
}
# exception_for <fichero> → las líneas que lo reincluyen desde el .gitignore del repo (que manda
# sobre core.excludesFile). Si se ignora una carpeta que lo contiene, git no mira dentro: hay que
# reincluir la carpeta. De .claude/, solo settings.json: lo demás suele ser local de cada persona.
exception_for() {
  local f="$1" d top=""
  case "$f" in .claude/settings.json) printf '%s\n' '!.claude/' '.claude/*' '!.claude/settings.json'; return 0 ;; esac
  d="$(dirname "$f")"
  while [ "$d" != "." ]; do
    git -C "$TARGET" check-ignore -q -- "$d/" 2>/dev/null && top="$d"
    d="$(dirname "$d")"
  done
  if [ -n "$top" ]; then printf '!%s/\n' "$top"; else printf '!%s\n' "$f"; fi
}
ignored=""; exceptions=""
while IFS= read -r f; do
  # -q decide (una excepción «!…» también aparece en -v, pero no ignora); -v solo dice qué regla
  git -C "$TARGET" check-ignore -q -- "$f" 2>/dev/null || continue
  why="$(git -C "$TARGET" check-ignore -v -- "$f" 2>/dev/null | cut -f1)"
  rest="${why#*:}"
  ignored="$ignored
      $f — lo ignora «${rest#*:}» (${why%%:*}, línea ${rest%%:*})"
  exceptions="$exceptions
$(exception_for "$f")"
done < <(versioned)
if [ -n "$ignored" ]; then
  exceptions="$(printf '%s\n' "$exceptions" | awk 'NF && !seen[$0]++' | sed 's/^/      /')"
  todo "el .gitignore deja fuera ficheros que hay que versionar:$ignored
    Sin ellos en git, tus compañeros no reciben el Centinela o la Esclusa, o la bitácora se queda
    en tu máquina. Añade al final del .gitignore del repo (vale aunque la regla venga de fuera,
    p. ej. de core.excludesFile):
$exceptions
    Compruébalo con: git check-ignore -v <fichero>"
fi

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
# tool). Con ids duplicados ya hay un pendiente que explica el bloqueo.
if [ -z "$dup" ]; then
  smoke_path="$(printf '%s' "$TARGET/smoke-test.txt" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
  while IFS='|' read -r what payload; do
    smoke_err="$(cd "$TARGET" && printf '%s' "$payload" \
      | env -u SENTINEL_POLICY -u SENTINEL_POLICY_DEFAULT -u SENTINEL_OVERRIDE -u SENTINEL_CONFIRM \
          CLAUDE_PROJECT_DIR="$TARGET" bash "$TARGET/sentinel/hooks/sentinel-guard.sh" 2>&1 >/dev/null)" && continue
    todo "el Centinela instalado deniega una acción inocua ($what): ${smoke_err#sentinel-guard: }
    Mientras siga así, el agente no podrá trabajar en este repo. Revisa sentinel/policy.yaml"
    break
  done <<EOF
\`true\` en shell|{"tool_name":"Bash","tool_input":{"command":"true"}}
leer un fichero|{"tool_name":"Read","tool_input":{"file_path":"$smoke_path"}}
editar un fichero|{"tool_name":"Edit","tool_input":{"file_path":"$smoke_path","old_string":"a","new_string":"b"}}
EOF
fi

echo
if [ "$pending" -eq 1 ]; then
  echo "Nivel Guardia instalado con pasos pendientes (⚠ arriba). Vuelve a ejecutar setup al resolverlos."
  exit 3
fi
echo "✓ Nivel Guardia instalado. Revisa git status y versiónalo en un commit: git add sentinel .claude .gitignore"
echo "  Comprueba en una sesión nueva de Claude Code, abierta en la raíz del repo, que /hooks muestra sentinel-guard."
exit 0
