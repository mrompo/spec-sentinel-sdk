#!/usr/bin/env bash
# sentinel-guard — el puesto Centinela de Shield (PreToolUse).
#
# Contrato: stdin = JSON del tool call.
#   exit 0            → la acción pasa (con JSON en stdout si hay aviso que el agente debe ver)
#   exit 2 + stderr   → denegada, con motivo (stderr sí se reinyecta al agente en exit 2)
#   stdout JSON ask   → requiere aprobación humana (permissionDecision del harness)
# Reglas (esquema v1 plano) en dos políticas:
#   1) sentinel/policy.default.yaml — la distribuida (viene con el SDK, la actualiza setup)
#   2) sentinel/policy.yaml         — la del consumidor (opcional; solo AÑADE protección)
# De todas las reglas que matchean, en las dos políticas, gana la decisión más estricta
# (block > confirm > warn) y, a igualdad, la primera (las del SDK van antes): ninguna regla que
# solo confirma o avisa tapa un bloqueo. Un id repetido es un error de política
# (opción A del slice 6 de git-gates, SC-sentinel-guard-17..21).
# Sin dependencias: bash + grep/sed. Endurecido tras el panel adversarial (ver §Limitaciones
# en sentinel/README.md: lo que este puesto NO puede garantizar lo cubren Esclusa y Aduana).
set -uo pipefail

# Anclaje: el project dir del harness manda (monorepo/submódulo/worktree), luego la raíz git.
REPO_ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
[ -d "$REPO_ROOT_DIR/sentinel" ] || REPO_ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DEFAULT_POLICY="${SENTINEL_POLICY_DEFAULT:-$REPO_ROOT_DIR/sentinel/policy.default.yaml}"
POLICY="${SENTINEL_POLICY:-$REPO_ROOT_DIR/sentinel/policy.yaml}"
OVERRIDES_LOG="${SENTINEL_OVERRIDES_LOG:-$REPO_ROOT_DIR/sentinel/overrides.log}"
OVERRIDE_TOKEN="$REPO_ROOT_DIR/sentinel/.override"

deny() { echo "sentinel-guard: $1" >&2; exit 2; }

json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g' | tr '\n' ' '; }

# ── Fail-closed (SC-02) ──────────────────────────────────────────────────────────────────
# La distribuida es obligatoria; la del consumidor, opcional, pero si existe tiene que leerse.
[ -f "$DEFAULT_POLICY" ] \
  || deny "política distribuida no encontrada ($DEFAULT_POLICY) — reinstala el SDK (setup) o exporta SENTINEL_POLICY_DEFAULT"
POLICIES="$DEFAULT_POLICY"
[ -f "$POLICY" ] && POLICIES="$DEFAULT_POLICY
$POLICY"
while IFS= read -r p; do
  grep -q '^version:' "$p" && grep -q '^rules:' "$p" \
    || deny "política ilegible ($p): faltan las claves 'version:' y/o 'rules:' — revisa el fichero"
done <<EOF
$POLICIES
EOF
ID_RE='^[[:space:]]*-[[:space:]]+id:[[:space:]]*'
RULE_COUNT="$(grep -cE "$ID_RE[^[:space:]]" "$DEFAULT_POLICY" || true)"
[ "${RULE_COUNT:-0}" -gt 0 ] \
  || deny "política sin reglas válidas ($DEFAULT_POLICY): 0 entradas '- id:' — una política vacía no protege nada"
# Un id del SDK repetido en la del consumidor: error de política, nunca sustitución (SC-19)
if [ -f "$POLICY" ]; then
  policy_ids() { sed -nE "s/$ID_RE([^[:space:]]+).*/\1/p" "$1" | LC_ALL=C sort -u; }
  DUP="$(LC_ALL=C comm -12 <(policy_ids "$DEFAULT_POLICY") <(policy_ids "$POLICY") | tr '\n' ' ')"
  [ -z "$DUP" ] \
    || deny "política del consumidor ($POLICY) repite ids del SDK: ${DUP% } — las reglas del SDK no se sustituyen: renombra o quita la tuya"
fi

# ── Contexto del tool call ───────────────────────────────────────────────────────────────
PAYLOAD="$(cat || true)"
[ -n "$PAYLOAD" ] || deny "sin payload: este hook espera el JSON del tool call por stdin"

# La acción ocurre en la carpeta de la sesión (el cwd del tool call), que no tiene por qué ser
# la del hook: las rutas relativas, los comodines y la rama se resuelven desde ahí. Vale el
# primer "cwd" del payload, el del tool call (revisión de sentinel-paths, V5)
_cwd="$(printf '%s' "$PAYLOAD" | grep -oE '"cwd"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -1 | sed -E 's/^"cwd"[[:space:]]*:[[:space:]]*"(.*)"$/\1/')"
[ -n "$_cwd" ] && [ -d "$_cwd" ] && cd "$_cwd" 2>/dev/null

TOOL_NAME="$(printf '%s' "$PAYLOAD" | sed -nE 's/.*"tool_name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1)"
[ -n "$TOOL_NAME" ] \
  || deny "payload sin 'tool_name' identificable — el guard no puede evaluar la acción (fail-closed)"

FILE_PATH="$(printf '%s' "$PAYLOAD" | sed -nE 's/.*"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\2/p' | head -1)"
COMMAND="$(printf '%s' "$PAYLOAD" | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1)"
# Contenido que se ESCRIBE (no old_string): evita bloquear la retirada de un .skip existente
NEW_CONTENT="$(printf '%s' "$PAYLOAD" | sed -nE 's/.*"(new_string|content|new_source)"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\2/p' | head -1)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
# sdd: lo declara el consumidor; si no lo hace, vale el de la distribuida
read_sdd() { sed -nE 's/^[[:space:]]*sdd:[[:space:]]*(true|false).*/\1/p' "$1" | head -1; }
POLICY_SDD=""
[ -f "$POLICY" ] && POLICY_SDD="$(read_sdd "$POLICY")"
[ -n "$POLICY_SDD" ] || POLICY_SDD="$(read_sdd "$DEFAULT_POLICY")"

# Ruta normalizada (./ y ../) para que el matching no dependa de cómo se escriba la ruta
NORM_PATH=""; RAW_PATH=""
if [ -n "$FILE_PATH" ]; then
  case "$FILE_PATH" in /*) NORM_PATH="$FILE_PATH" ;; *) NORM_PATH="$PWD/$FILE_PATH" ;; esac
  RAW_PATH="$NORM_PATH"
  while printf '%s' "$NORM_PATH" | grep -q '/\./'; do NORM_PATH="$(printf '%s' "$NORM_PATH" | sed 's|/\./|/|g')"; done
  while printf '%s' "$NORM_PATH" | grep -q '/[^/][^/]*/\.\./'; do
    NORM_PATH="$(printf '%s' "$NORM_PATH" | sed 's|/[^/][^/]*/\.\./|/|')"
  done
  # Ruta relativa al repo: las reglas se escriben en términos del proyecto, no del disco
  REL_PATH="${NORM_PATH#$REPO_ROOT_DIR/}"
else
  REL_PATH=""
fi

# ── Lo que se toca, no cómo se escribe (sentinel-paths, SC-sentinel-paths-01..03, 07) ────
# Cada ruta de la acción (el file_path, y las palabras del comando que son rutas) se resuelve a
# su ruta física y se nombra como la nombra la política: la configuración de git real del repo
# es «.git/…» aunque viva en .bare/, la de Claude Code de la persona es «.claude/…» aunque
# CLAUDE_CONFIG_DIR la ponga en otra carpeta, y lo del repo va relativo a su raíz. Las reglas
# de ruta ven la ruta escrita y la física; las de carpeta (dir_re), la física de cada palabra.
phys_dir() { (cd -P "$1" 2>/dev/null && pwd -P); }

# phys_path <ruta absoluta> → la ruta física: resuelve los enlaces de sus carpetas (desde la
# carpeta padre que exista) y los del propio fichero, aunque el fichero aún no exista
phys_path() {
  local p="$1" d b rest t n=0
  while [ "$n" -lt 40 ]; do
    if [ -d "$p" ]; then phys_dir "$p" || printf '%s' "$p"; return; fi
    d="${p%/*}"; b="${p##*/}"; [ -n "$d" ] || d=/
    rest=""
    while [ ! -d "$d" ]; do rest="/${d##*/}$rest"; d="${d%/*}"; [ -n "$d" ] || d=/; done
    d="$(phys_dir "$d")" || { printf '%s' "$p"; return; }
    p="${d%/}$rest/$b"
    { [ -z "$rest" ] && [ -L "$p" ]; } || break
    t="$(readlink "$p")"
    case "$t" in /*) p="$t" ;; *) p="${d%/}/$t" ;; esac
    n=$((n+1))
  done
  printf '%s' "$p"
}

REPO_PHYS="$(phys_dir "$REPO_ROOT_DIR")"; [ -n "$REPO_PHYS" ] || REPO_PHYS="$REPO_ROOT_DIR"
# git_common <carpeta> → la carpeta común de git de su repo, física
git_common() {
  local d; d="$(git -C "$1" rev-parse --git-common-dir 2>/dev/null)" || return 1
  case "$d" in /*) ;; *) d="$1/$d" ;; esac
  phys_dir "$d"
}
# La configuración de git real es la del proyecto, se ejecute la acción donde se ejecute
# (revisión de sentinel-paths, A4)
GIT_COMMON_PHYS="$(git_common "$REPO_ROOT_DIR")"
CLAUDE_CFG="${CLAUDE_CONFIG_DIR:-${HOME:-/nonexistent}/.claude}"
CLAUDE_CFG_PHYS="$(phys_dir "$CLAUDE_CFG")"

# canon <ruta física> → cómo la nombra la política. Si cae dentro de varias raíces, gana la más
# cercana, la más larga: un worktree que vive dentro de su repo bare es el repo, no su
# configuración de git (revisión de sentinel-paths, P2)
canon() {
  local p="$1" out="$1" best=0
  if [ -n "$GIT_COMMON_PHYS" ]; then
    case "$p" in "$GIT_COMMON_PHYS"|"$GIT_COMMON_PHYS"/*) out=".git${p#"$GIT_COMMON_PHYS"}"; best=${#GIT_COMMON_PHYS} ;; esac
  fi
  if [ -n "$CLAUDE_CFG_PHYS" ] && [ "${#CLAUDE_CFG_PHYS}" -gt "$best" ]; then
    case "$p" in "$CLAUDE_CFG_PHYS"|"$CLAUDE_CFG_PHYS"/*) out=".claude${p#"$CLAUDE_CFG_PHYS"}"; best=${#CLAUDE_CFG_PHYS} ;; esac
  fi
  if [ "${#REPO_PHYS}" -gt "$best" ]; then
    case "$p" in "$REPO_PHYS") out=. ;; "$REPO_PHYS"/*) out="${p#"$REPO_PHYS"/}" ;; esac
  fi
  printf '%s' "$out"
}

# La configuración de la persona que vive fuera del repo, por su ruta física: un fichero del
# repo que es esa configuración (~/.gitconfig enlaza a dotfiles/.gitconfig) se nombra «~/…»
# (SC-sentinel-paths-04)
PERSONAL=""
for _f in .gitconfig .config/git/config .jq; do
  [ -n "${HOME:-}" ] || break
  PERSONAL="$PERSONAL
$(phys_path "$HOME/$_f")	~/$_f"
done

TOUCHED=""   # ruta física de cada cosa que toca la acción, tal como la nombra la política
PHYS_ALL=""  # y su ruta física absoluta
add_target() { # $1=ruta absoluta
  local ph line; ph="$(phys_path "$1")"
  TOUCHED="$TOUCHED
$(canon "$ph")"
  PHYS_ALL="$PHYS_ALL
$ph"
  while IFS= read -r line; do
    [ "${line%%	*}" = "$ph" ] && TOUCHED="$TOUCHED
${line#*	}"
  done <<EOF
$PERSONAL
EOF
}
[ -n "$NORM_PATH" ] && add_target "$NORM_PATH"
# Sin normalizar, como la resuelve el sistema: un '..' detrás de un enlace sube desde donde
# apunta el enlace (revisión de sentinel-paths, A7)
[ -n "$RAW_PATH" ] && [ "$RAW_PATH" != "$NORM_PATH" ] && add_target "$RAW_PATH"
# json_text → el comando tal como lo recibe bash: los escapes del JSON deshechos (\n es un
# salto de línea, \t un tabulador, \u00XX su carácter, con los pares sustitutos)
json_text() {
  printf '%s' "$COMMAND" | LC_ALL=C awk '
    function hex(h,   k, x, v) {
      if (length(h) < 4) return -1
      v = 0
      for (k = 1; k <= 4; k++) {
        x = index("0123456789abcdef", tolower(substr(h, k, 1)))
        if (!x) return -1
        v = v * 16 + x - 1
      }
      return v
    }
    function utf8(v) {
      if (v == 0) return ""
      if (v < 128) return sprintf("%c", v)
      if (v < 2048) return sprintf("%c%c", 192 + int(v / 64), 128 + v % 64)
      if (v < 65536) return sprintf("%c%c%c", 224 + int(v / 4096), 128 + int(v / 64) % 64, 128 + v % 64)
      return sprintf("%c%c%c%c", 240 + int(v / 262144), 128 + int(v / 4096) % 64, 128 + int(v / 64) % 64, 128 + v % 64)
    }
    { s = (NR > 1 ? s "\n" : "") $0 }
    END {
      t = ""; n = length(s)
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (c == "\\" && i < n) {
          d = substr(s, ++i, 1)
          if (d == "n") t = t "\n"; else if (d == "r") t = t "\r"; else if (d == "t") t = t "\t"
          else if (d == "b") t = t "\b"; else if (d == "f") t = t "\f"
          else if (d == "u" && (v = hex(substr(s, i + 1, 4))) >= 0) {
            i += 4
            if (v >= 55296 && v < 56320 && substr(s, i + 1, 2) == "\\u" \
                && (lo = hex(substr(s, i + 3, 4))) >= 56320 && lo < 57344) {
              i += 6; v = 65536 + (v - 55296) * 1024 + (lo - 56320)
            }
            t = t utf8(v)
          }
          else t = t d
        } else t = t c
      }
      printf "%s", t
    }'
}

# cmd_words <texto> → una palabra del comando por línea, como la vería la shell: respeta '…' y
# "…" (una ruta con espacios es una sola palabra; dentro de "…" la barra solo escapa $ ` " \ y
# el salto de línea) y el escape con '\', y parte por espacios, separadores (; | & ( ) ` y el
# salto de línea), redirecciones (< >) y '=' (--file=x, include.path=x). Cada palabra sale con
# '\' y el salto de línea escapados (\\ y \n), para que una palabra con saltos siga en una sola
# línea; quien la lee la deshace con printf %b. Sale como 'l<palabra>', precedida de
# 'g<patrón>' si lleva un comodín sin comillas (* ? [): en el patrón, lo que iba entre comillas
# o escapado se escapa con '\', como lo vería la shell. Cada separador sale como 's', y cada
# tramo, como 'n<tramo>': sus palabras separadas por un espacio, cada una por su nombre (lo
# que sigue a su última '/') y con sus espacios cambiados por '_', para que las reglas del
# comando reconozcan el programa se escriba como se escriba (/bin/mv, \mv, 'mv'). Lo que bash
# no lee como palabras no abre comillas que se coman las líneas siguientes (revisión de la
# #15): un comentario (# al principio de una palabra) se salta hasta el final de la línea; en
# $'…' la barra escapa la comilla (su contenido no se expande); y el cuerpo de un heredoc
# (<<FIN, <<-FIN, <<'FIN') se lee línea a línea, sin comillas que pasen de una a otra ni
# comentarios, hasta la línea que lo cierra: sus palabras siguen contando, así que un << que
# no abre un heredoc (el de una expresión aritmética) no esconde nada
cmd_words() {
  printf '%s' "$1" | LC_ALL=C awk '
    function esc(x,   r, k, ch) {
      r = ""
      for (k = 1; k <= length(x); k++) {
        ch = substr(x, k, 1)
        if (ch == "\\") r = r "\\\\"; else if (ch == "\n") r = r "\\n"; else r = r ch
      }
      return r
    }
    function flush(   b) {
      if (has) {
        if (g) print "g" esc(pw)
        print "l" esc(w)
        b = w
        if (b ~ /\/./) { sub(/\/+$/, "", b); sub(/^.*\//, "", b) }
        gsub(/[ \t\n\r]/, "_", b)
        seg = seg (seg == "" ? "" : " ") b
      }
      w = ""; pw = ""; has = 0; g = 0
    }
    function sep() { flush(); if (seg != "") print "n" seg; seg = ""; print "s" }
    function lit(ch) { w = w ch; pw = pw (index("*?[]\\", ch) ? "\\" ch : ch) }
    # hend → tras un salto de línea dentro de un heredoc: si la línea siguiente lo cierra, la
    # salta y pasa al siguiente heredoc pendiente de la misma línea, o sale del cuerpo
    function hend(   j, line) {
      while (hb) {
        j = index(substr(t, i + 1), "\n")
        line = j ? substr(t, i + 1, j - 1) : substr(t, i + 1)
        if (hs[hq]) sub(/^\t+/, "", line)
        if (line != hd[hq]) return
        i = j ? i + j : n
        if (++hq > hn) { hb = 0; hn = 0; hq = 1 }
      }
    }
    { t = (NR > 1 ? t "\n" : "") $0 }
    END {
      n = length(t); q = ""; w = ""; pw = ""; has = 0; g = 0; seg = ""
      hb = 0; hn = 0; hq = 1
      for (i = 1; i <= n; i++) {
        c = substr(t, i, 1)
        if (hb && c == "\n") q = ""
        if (q == "\047") { if (c == q) q = ""; else lit(c); continue }
        if (q == "$") {
          if (c == "\\" && i < n) { lit(c); lit(substr(t, ++i, 1)) }
          else if (c == "\047") q = ""
          else lit(c)
          continue
        }
        if (q == "\"") {
          if (c == "\"") q = ""
          else if (c == "\\" && i < n) {
            d = substr(t, ++i, 1)
            if (d != "\n") { if (index("$`\"\\", d)) lit(d); else { lit(c); lit(d) } }
          }
          else lit(c)
          continue
        }
        if (c == "$" && substr(t, i + 1, 1) == "\047") { q = "$"; i++; has = 1; continue }
        if (c == "\047" || c == "\"") { q = c; has = 1; continue }
        if (c == "\\" && i < n) { d = substr(t, ++i, 1); if (d != "\n") { lit(d); has = 1 }; continue }
        if (!hb && c == "#" && !has && (i == 1 || index(" \t\n;|&()`", substr(t, i - 1, 1)))) {
          while (i < n && substr(t, i + 1, 1) != "\n") i++
          continue
        }
        if (!hb && c == "<" && substr(t, i + 1, 1) == "<") {
          flush(); i += 2; st = 0
          if (substr(t, i, 1) == "-") { st = 1; i++ }
          while (i <= n && index(" \t", substr(t, i, 1))) i++
          dl = ""
          while (i <= n && !index(" \t\n;|&()<>", (ch = substr(t, i, 1)))) {
            if (ch == "\047" || ch == "\"") {
              k = index(substr(t, i + 1), ch)
              if (!k) { dl = dl substr(t, i + 1); i = n + 1; break }
              dl = dl substr(t, i + 1, k - 1); i += k + 1; continue
            }
            if (ch == "\\" && i < n) { dl = dl substr(t, i + 1, 1); i += 2; continue }
            dl = dl ch; i++
          }
          hd[++hn] = dl; hs[hn] = st
          i--
          continue
        }
        if (c == "\n") { sep(); if (hq <= hn) { hb = 1; hend() }; continue }
        if (index(";|&()`", c)) { sep(); continue }
        if (index(" \t<>=", c)) { flush(); continue }
        w = w c; pw = pw c; has = 1; if (index("*?[", c)) g = 1
      }
      sep()
    }'
}

# tilde → $_w: la palabra con ~, $HOME y $CLAUDE_CONFIG_DIR delante ya sustituidos
tilde() {
  _w="$1"
  case "$_w" in
    "~"|"~/"*) _w="${HOME:-}${_w#"~"}" ;;
    '$HOME'|'$HOME/'*) _w="${HOME:-}${_w#'$HOME'}" ;;
    '${HOME}'|'${HOME}/'*) _w="${HOME:-}${_w#'${HOME}'}" ;;
    '$CLAUDE_CONFIG_DIR'|'$CLAUDE_CONFIG_DIR/'*) _w="$CLAUDE_CFG${_w#'$CLAUDE_CONFIG_DIR'}" ;;
    '${CLAUDE_CONFIG_DIR}'|'${CLAUDE_CONFIG_DIR}/'*) _w="$CLAUDE_CFG${_w#'${CLAUDE_CONFIG_DIR}'}" ;;
  esac
}
# glob_matches → las coincidencias de un patrón en el disco, separadas por NUL, con las opciones
# por defecto de la shell (sin ficheros ocultos salvo que el patrón empiece por '.')
glob_matches() (
  unset GLOBIGNORE
  shopt -u dotglob nocaseglob failglob extglob globstar 2>/dev/null
  shopt -s nullglob
  IFS=
  for f in $1; do printf '%s\0' "$f"; done
)
# add_word → cuenta como ruta la palabra que existe, o que lleva '/' y cuya carpeta existe (en
# una carpeta que no existe no se escribe: el texto de un heredoc o una URL no son rutas),
# también si empieza por '-' (tras '--' es una ruta, y una opción como -rf no existe ni lleva
# '/'). Si el comando nombra más rutas de las que el guard comprueba, no se puede saber qué
# toca: lo decide la regla too-many-paths, que bloquea y que la llave de esa acción salva
# (revisión de sentinel-paths, P5 = A8). Dejar de mirar a partir de la N dejaría pasar la N+1.
# TOO_MANY guarda el motivo
MAX_PATHS=512
_n=0; TOO_MANY=""
add_word() {
  local w o
  [ -n "$1" ] || return
  tilde "$1"; o="$_w"; w="$_w"
  case "$w" in /*) ;; *) w="$PWD/$w" ;; esac
  while :; do
    case "$w" in /) break ;; */) w="${w%/}" ;; */.) w="${w%/.}" ;; *) break ;; esac
  done
  if [ ! -e "$w" ] && [ ! -L "$w" ]; then
    case "$o" in */*) ;; *) return ;; esac
    [ -d "${w%/*}/" ] || return
  fi
  _n=$((_n+1))
  [ "$_n" -le "$MAX_PATHS" ] || {
    TOO_MANY="el comando nombra más de $MAX_PATHS rutas y el Centinela no puede comprobarlas todas — pártelo en comandos más cortos"
    return
  }
  add_target "$w"
}

# add_tree <destino> <carpeta de origen> → lo que deja en el destino copiar, mover o enlazar
# una carpeta: cada entrada del origen, con su ruta relativa, dentro del destino. El destino se
# resuelve una vez y cada entrada cuelga de él, salvo la que ya está allí como enlace, que
# escribe donde apunta (revisión de la #17). Si el origen tiene más entradas de las que el guard
# comprueba, o alguna que no puede leer, no se sabe qué deja: lo decide too-many-paths
MAX_TREE=10000
add_tree() {
  local s="$2" ph cn out line p r
  case "$s" in /*) ;; *) s="$PWD/$s" ;; esac
  [ -d "$s" ] || return 0
  # Lo que find no puede leer sale como «find: …» (una entrada sale como «./…»); que head corte
  # la salida no lo es
  out="$(cd "$s" 2>/dev/null && { find . -mindepth 1 2>&1 || true; } | head -n "$((MAX_TREE + 1))")" ||
    out="find: $s"
  case "$out" in
    "find: "*|*$'\n'"find: "*)
      TOO_MANY="el comando copia o enlaza una carpeta que el Centinela no puede leer entera ($2) y no sabe qué deja en el destino"
      return ;;
  esac
  [ -n "$out" ] || return 0
  [ "$(printf '%s\n' "$out" | wc -l)" -le "$MAX_TREE" ] || {
    TOO_MANY="el comando copia o enlaza una carpeta de más de $MAX_TREE entradas ($2) y el Centinela no puede comprobarlas todas — cópiala por partes"
    return
  }
  out="$(printf '%s\n' "$out" | sed 's|^\./||')"
  ph="$(phys_path "$1")"; cn="$(canon "$ph")"
  [ "$cn" = . ] && cn=""
  TOUCHED="$TOUCHED
$(printf '%s\n' "$out" | C="${cn:+$cn/}" awk '{ print ENVIRON["C"] $0 }')"
  # La configuración de la persona, como en add_target
  while IFS= read -r line; do
    p="${line%%	*}"
    case "$p" in
      "${ph%/}"/*)
        printf '%s\n' "$out" | grep -qxF -- "${p#"${ph%/}"/}" && TOUCHED="$TOUCHED
${line#*	}" ;;
    esac
  done <<EOF
$PERSONAL
EOF
  while IFS= read -r r; do
    [ -L "$ph/$r" ] || continue
    add_target "$ph/$r"
    add_tree "$ph/$r" "$s/$r"
  done <<EOF
$out
EOF
}

# into_dir <palabras de un tramo> → copiar, mover o enlazar a una carpeta toca, dentro de ella,
# un fichero con el nombre de cada origen: «cp x/config .git» escribe .git/config aunque el
# comando no lo nombre (revisión de sentinel-paths, A1). Revisión de la #16: el programa es la
# primera palabra del tramo que copia, mueve o enlaza, también detrás de un prefijo de
# ejecución (sudo, env, command…) o de una asignación (que el lector parte por el '='); esa
# palabra entre los argumentos de otro programa solo puede añadir rutas. El contenido de una
# carpeta (rsync con '/' al final, -T; 'carpeta/.' ya lo es) va directamente al destino, y lo
# que hay dentro de una carpeta copiada o enlazada también se toca
into_dir() {
  local v="" dest="" w b t=0 opts=1 tdir=0 srcs=()
  while [ "$#" -gt 0 ]; do
    case "${1##*/}" in cp|mv|ln|install|rsync) v="${1##*/}"; break ;; esac
    shift
  done
  [ -n "$v" ] || return 0
  shift
  for w in "$@"; do
    if [ "$t" = 1 ]; then dest="$w"; t=0; continue; fi
    if [ "$opts" = 1 ]; then
      case "$w" in
        --) opts=0; continue ;;
        --target-directory) t=1; continue ;;
        --no-target-directory) tdir=1; continue ;;
        --*) continue ;;
        -*)
          # rsync -t conserva las fechas; en los demás, -t lleva la carpeta de destino, también
          # dentro de un grupo (-rt carpeta, -tcarpeta)
          if [ "$v" != rsync ]; then
            case "$w" in *T*) tdir=1 ;; esac
            case "$w" in *t*) b="${w#*t}"; if [ -n "$b" ]; then dest="$b"; else t=1; fi ;; esac
          fi
          continue ;;
      esac
    fi
    srcs+=("$w")
  done
  if [ -z "$dest" ]; then
    [ "${#srcs[@]}" -ge 2 ] || return 0
    dest="${srcs[${#srcs[@]}-1]}"
    unset "srcs[${#srcs[@]}-1]"
  fi
  tilde "$dest"; dest="$_w"
  case "$dest" in /*) ;; *) dest="$PWD/$dest" ;; esac
  [ -d "$dest" ] || return 0
  for w in ${srcs[@]+"${srcs[@]}"}; do
    tilde "$w"; w="$_w"
    case "$tdir:$v:$w" in 1:*|*:rsync:*/) add_tree "$dest" "$w"; continue ;; esac
    b="$w"
    while case "$b" in ?*/) true ;; *) false ;; esac; do b="${b%/}"; done
    b="${b##*/}"
    [ -n "$b" ] || continue
    add_word "${dest%/}/$b"
    add_tree "${dest%/}/$b" "$w"
  done
}

# El comando como lo recibe bash, sus palabras y sus tramos (los ven las reglas del comando)
CMD_TEXT=""; WORDS=""; CMD_NORM=""
if [ -n "$COMMAND" ]; then
  CMD_TEXT="$(json_text)"
  WORDS="$(cmd_words "$CMD_TEXT")"
  CMD_NORM="$(printf '%s\n' "$WORDS" | sed -n 's/^n//p')"
fi

if [ -n "$COMMAND" ]; then
  # Un patrón con coincidencias cuenta por ellas; sin coincidencias, la shell deja la palabra tal cual
  _globbed=0
  while IFS= read -r w; do
    _k="${w:0:1}"
    case "$_k" in g|l) ;; *) continue ;; esac
    printf -v w '%b' "${w:1}"
    if [ "$_k" = g ]; then
      tilde "$w"; _globbed=0
      while IFS= read -r -d '' f; do _globbed=1; add_word "$f"; done < <(glob_matches "$_w")
      continue
    fi
    [ "$_globbed" = 1 ] && { _globbed=0; continue; }
    add_word "$w"
  done <<EOF
$WORDS
EOF
  # Lo que cada tramo copia, mueve o enlaza a una carpeta, con los comodines ya expandidos
  _seg=(); _globbed=0
  while IFS= read -r w; do
    case "${w:0:1}" in
      g)
        printf -v w '%b' "${w:1}"; tilde "$w"; _globbed=0
        while IFS= read -r -d '' f; do _globbed=1; _seg+=("$f"); done < <(glob_matches "$_w") ;;
      l)
        [ "$_globbed" = 1 ] && { _globbed=0; continue; }
        printf -v w '%b' "${w:1}"; _seg+=("$w") ;;
      s) [ "${#_seg[@]}" -gt 0 ] && into_dir "${_seg[@]}"; _seg=(); _globbed=0 ;;
    esac
  done <<EOF
$WORDS
EOF
fi

# Superficie de rutas: relativa al repo + absoluta + comando (un shell toca ficheros sin
# file_path), también decodificado, + la ruta física de lo que se toca, nombrada como la
# política y absoluta
PATH_SURFACE="$REL_PATH
$FILE_PATH
$COMMAND
$CMD_TEXT$TOUCHED$PHYS_ALL"
# Superficie del comando: tal como llega, con los escapes del JSON deshechos y sus tramos como
# los ve bash (sin comillas ni escapes, cada programa por su nombre). Cada forma solo puede
# hacer que una regla case más, nunca menos
CMD_SURFACE="$COMMAND
$CMD_TEXT
$CMD_NORM"

ACTIVE_CHANGE=""
if [ -d "$REPO_ROOT_DIR/openspec/changes" ]; then
  ACTIVE_CHANGE="$(find "$REPO_ROOT_DIR/openspec/changes" -mindepth 1 -maxdepth 1 -type d ! -name archive 2>/dev/null | head -1)"
fi

ACTION_DESC="${TOOL_NAME}:${COMMAND:-${REL_PATH:-$FILE_PATH}}"

# ── Solo lee (SC-sentinel-paths-08) ──────────────────────────────────────────────────────
# Lista cerrada, sin parser de shell: el comando solo lee si cada tramo (partido como lo parte
# bash: un separador entre comillas no parte nada) empieza por un lector conocido, sin
# redirecciones (salvo a /dev/null y 2>&1), sustituciones, asignaciones ni opciones que
# escriben. Ante la duda, no solo lee y se evalúa como siempre. Lo aplican las reglas con
# skip_read_only: true.
ro_segment() { # "$@" = las palabras de un tramo, sin comillas ni escapes → 0 si solo lee
  local w
  [ "$#" -gt 0 ] || return 0
  case "$1" in
    cat|head|tail|wc|grep|ls|stat|diff|cmp|cut|tr|nl|echo|printf|true|cd) ;;
    git) case "${2:-}" in diff|log|show|status|blame|ls-files|rev-parse|cat-file) ;; *) return 1 ;; esac ;;
    *) return 1 ;;
  esac
  for w in "$@"; do
    # --output escribe un fichero; printf -v asigna una variable
    case "$w" in --output|--output=*) return 1 ;; esac
    if [ "$1" = printf ]; then case "$w" in -v*) return 1 ;; esac; fi
  done
  return 0
}
is_read_only() {
  local c w k seg=()
  [ "$TOOL_NAME" = Bash ] && [ -n "$CMD_TEXT" ] || return 1
  c="$CMD_TEXT"
  case "$c" in *'$('*|*'`'*|*'<('*|*'>('*|*'<>'*) return 1 ;; esac
  # Las redirecciones a /dev/null y entre descriptores (2>&1) no escriben: se quitan, también
  # pegadas a un separador o seguidas, hasta que no quede ninguna
  while :; do
    w="$(printf '%s' "$c" | sed -E -e 's#(^|[[:space:];&|])(&|[0-9])?>>?[[:space:]]*/dev/null([[:space:];&|]|$)#\1 \3#g' -e 's#(^|[[:space:];&|])[0-9]?>&[0-9]([[:space:];&|]|$)#\1 \2#g')"
    [ "$w" = "$c" ] && break
    c="$w"
  done
  case "$c" in *'>'*|*'<'*) return 1 ;; esac
  while IFS= read -r w; do
    k="${w:0:1}"
    case "$k" in
      l) printf -v w '%b' "${w:1}"; seg+=("$w") ;;
      s) ro_segment ${seg[@]+"${seg[@]}"} || return 1; seg=() ;;
    esac
  done <<EOF
$(cmd_words "$c")
EOF
  ro_segment ${seg[@]+"${seg[@]}"}
}
READ_ONLY=false
is_read_only && READ_ONLY=true

# ── Break-glass auditado ─────────────────────────────────────────────────────────────────
# Dos vías, ambas fuera del alcance del agente (la política protege sentinel/**):
#   1) SENTINEL_OVERRIDE exportado en el entorno de la sesión (afecta a la sesión entera)
#   2) sentinel/.override con el motivo y `para: <acción>` → token de UN SOLO USO, que solo
#      gasta la acción cuya descripción es exactamente la de su para: (SC-sentinel-paths-05)
token_para()   { sed -nE 's/^[[:space:]]*para:[[:space:]]*//p' "$OVERRIDE_TOKEN" 2>/dev/null | head -1 | sed -E 's/[[:space:]]+$//'; }
token_motivo() { grep -vE '^[[:space:]]*para:' "$OVERRIDE_TOKEN" 2>/dev/null | tr '\n' ' ' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }
override_reason() {
  local motivo
  if [ -n "${SENTINEL_OVERRIDE:-}" ] && [ -n "$(printf '%s' "$SENTINEL_OVERRIDE" | tr -d '[:space:]')" ]; then
    printf '%s' "$SENTINEL_OVERRIDE"; return 0
  fi
  [ -s "$OVERRIDE_TOKEN" ] || return 1
  motivo="$(token_motivo)"
  [ -n "$motivo" ] && [ "$(token_para)" = "$ACTION_DESC" ] || return 1
  printf '%s' "$motivo"
}

# key_hint → la llave de ESTA acción, lista para copiar, y por qué no vale la que hay
key_hint() {
  local why=""
  if [ -s "$OVERRIDE_TOKEN" ]; then
    if [ -z "$(token_para)" ]; then why="la llave de sentinel/.override no dice para qué acción es (falta 'para:'): no autoriza nada y se conserva"
    elif [ -z "$(token_motivo)" ]; then why="la llave de sentinel/.override no tiene motivo: no vale y se conserva"
    else why="la llave de sentinel/.override es para otra acción ($(token_para)): se conserva"
    fi
    why="
  Ojo: $why."
  fi
  printf '%s\n  Excepción auditada para esta acción: una persona, desde su terminal, escribe la llave\n    cat > sentinel/.override <<'"'"'LLAVE'"'"'\n    <motivo>\n    para: %s\n    LLAVE' "$why" "$ACTION_DESC"
}

log_override() { # $1=id de regla, $2=motivo — auditoría verificada (si no se puede escribir, se deniega)
  local line
  line="$(printf '%s | %s | %s | %s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$(printf '%s' "$ACTION_DESC" | tr '\n' ' ')" "$(printf '%s' "$2" | tr '\n' ' ')")"
  mkdir -p "$(dirname "$OVERRIDES_LOG")" 2>/dev/null
  printf '%s\n' "$line" >> "$OVERRIDES_LOG" 2>/dev/null \
    || deny "[$1] override rechazado: no se pudo escribir la auditoría en $OVERRIDES_LOG — sin registro no hay excepción"
  [ -f "$OVERRIDE_TOKEN" ] && rm -f "$OVERRIDE_TOKEN"   # token de un solo uso
  return 0
}

# ── Decisión por modo ────────────────────────────────────────────────────────────────────
rule_matched() { # $1=id $2=mode $3=reason — no retorna
  local id="$1" mode="$2" reason="$3" why
  case "$mode" in
    warn)
      # stderr para el humano + JSON para que el agente lo vea (con exit 0 stderr no se reinyecta)
      echo "sentinel-guard[warn:$id]: $reason" >&2
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"sentinel-guard[warn:%s]: %s"}}\n' \
        "$(json_escape "$id")" "$(json_escape "$reason")"
      exit 0
      ;;
    block|confirm)
      if why="$(override_reason)"; then
        log_override "$id" "$why"
        echo "sentinel-guard[override:$id]: permitido y auditado — $why" >&2
        exit 0
      fi
      if [ "$mode" = "confirm" ]; then
        # Aprobación humana POR ACCIÓN vía el mecanismo de permisos del harness
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"sentinel-guard[%s]: %s"}}\n' \
          "$(json_escape "$id")" "$(json_escape "$reason")"
        exit 0
      fi
      deny "[$id] $reason$(key_hint)"
      ;;
    *)
      deny "[$id] modo desconocido '$mode' en la política — corrige $CUR_POLICY"
      ;;
  esac
}

# ── Evaluación de reglas ─────────────────────────────────────────────────────────────────
reset_rule() { r_id=""; r_tool=""; r_command_re=""; r_path_re=""; r_dir_re=""; r_content_re=""; r_branch_re=""; r_mode=""; r_reason=""; r_requires_sdd=""; r_no_active=""; r_skip_ro=""; }

# rank <modo> → cuánto restringe, para quedarse con la decisión más estricta
rank() { case "$1" in block) echo 3 ;; confirm) echo 2 ;; warn) echo 1 ;; *) echo 0 ;; esac; }

# apply_rule → 0 si la regla en curso matchea, 1 si no. Si matchea y es más estricta que la que
# ya había en m_id, m_mode, m_reason, m_policy, la sustituye; a igualdad se queda la primera.
apply_rule() {
  [ -n "$r_id" ] || return 1
  # Regla malformada = error de política, no permiso silencioso (fail-closed)
  [ -n "$r_mode" ] || deny "[${r_id}] regla sin 'mode:' en la política — corrige $CUR_POLICY"
  if [ "$r_requires_sdd" = "true" ] && [ "$POLICY_SDD" != "true" ]; then return 1; fi
  if [ "$r_no_active" = "true" ] && [ -n "$ACTIVE_CHANGE" ]; then return 1; fi
  if [ "$r_skip_ro" = "true" ] && [ "$READ_ONLY" = true ]; then return 1; fi
  # match: 0 = matchea · 1 = no matchea · 2+ = regex inválida → error de política (fail-closed),
  # nunca "regla que no aplica" en silencio.
  match() { # $1=texto $2=regex [$3=-i]
    printf '%s' "$1" | grep -qE ${3:-} -- "$2" 2>/dev/null
    local rc=$?
    [ "$rc" -le 1 ] && return $rc
    deny "[${r_id}] regex inválida en la política ('$2') — corrige $CUR_POLICY"
  }

  if [ -n "$r_tool" ]; then match "$TOOL_NAME" "^($r_tool)$" || return 1; fi
  if [ -n "$r_command_re" ]; then
    [ -n "$COMMAND" ] || return 1
    match "$CMD_SURFACE" "$r_command_re" || return 1
  fi
  if [ -n "$r_path_re" ]; then
    match "$PATH_SURFACE" "$r_path_re" -i || return 1
  fi
  if [ -n "$r_dir_re" ]; then
    # una línea por cosa tocada: la regex se ancla a la ruta entera (^…$)
    match "$TOUCHED" "$r_dir_re" || return 1
  fi
  if [ -n "$r_content_re" ]; then
    # solo contra lo que se escribe (+ comando en Bash), nunca contra old_string
    match "$(printf '%s\n%s' "$NEW_CONTENT" "$COMMAND")" "$r_content_re" || return 1
  fi
  if [ -n "$r_branch_re" ]; then match "$BRANCH" "$r_branch_re" || return 1; fi
  case "$r_mode" in
    block|confirm|warn) ;;
    *) deny "[$r_id] modo desconocido '$r_mode' en la política — corrige $CUR_POLICY" ;;
  esac
  # Se queda con la más estricta de las que matchean; a igualdad, con la primera
  if [ -z "$m_id" ] || [ "$(rank "$r_mode")" -gt "$(rank "$m_mode")" ]; then
    m_id="$r_id"; m_mode="$r_mode"; m_reason="$r_reason"; m_policy="$CUR_POLICY"
  fi
  return 0
}

# Parser v1: clave al inicio de línea (tras indentación); comentarios en cualquier columna
# se ignoran; el valor conserva todo lo que sigue a los dos puntos (los '#' inline se recortan
# solo si van precedidos de espacio, para no romper regex que contengan '#').
kv() { # $1=línea $2=clave → 0 si la línea define esa clave
  case "$1" in "$2:"*|"$2: "*) return 0 ;; *) return 1 ;; esac
}
val() {
  local v="${1#*:}"
  v="${v# }"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

# eval_policy <fichero> → de las reglas del fichero que matchean, la más estricta queda en m_*
# (m_id vacío si ninguna; a igualdad, la primera). En cuanto una bloquea ya no hay nada más
# estricto, así que deja de mirar.
eval_policy() {
  CUR_POLICY="$1"; m_id=""; m_mode=""; m_reason=""; m_policy=""
  reset_rule
  while IFS= read -r raw || [ -n "$raw" ]; do
    line="${raw#"${raw%%[![:space:]]*}"}"          # sin indentación
    case "$line" in \#*|"") continue ;; esac        # comentario en cualquier columna
    case "$line" in
      "- id:"*|"-  id:"*)
        apply_rule || true
        [ "$m_mode" = block ] && return 0
        reset_rule; r_id="$(val "${line#-}")" ;;
      *)
        if   kv "$line" "tool";                     then r_tool="$(val "$line")"
        elif kv "$line" "command_re";               then r_command_re="$(val "$line")"
        elif kv "$line" "path_re";                  then r_path_re="$(val "$line")"
        elif kv "$line" "dir_re";                   then r_dir_re="$(val "$line")"
        elif kv "$line" "content_re";               then r_content_re="$(val "$line")"
        elif kv "$line" "branch_re";                then r_branch_re="$(val "$line")"
        elif kv "$line" "only_if_no_active_change"; then r_no_active="$(val "$line")"
        elif kv "$line" "requires_sdd";             then r_requires_sdd="$(val "$line")"
        elif kv "$line" "skip_read_only";           then r_skip_ro="$(val "$line")"
        elif kv "$line" "mode";                     then r_mode="$(val "$line")"
        elif kv "$line" "reason";                   then r_reason="$(val "$line")"
        fi ;;
    esac
  done < "$1"
  apply_rule || true
}

# Más rutas o entradas de las que el guard comprueba, o una carpeta que no puede leer: no se sabe
# qué toca el comando, así que se bloquea, y la llave de esa acción lo salva (revisión de
# sentinel-paths, P5 = A8, y de la #17)
if [ -n "$TOO_MANY" ]; then
  CUR_POLICY="$DEFAULT_POLICY"
  rule_matched too-many-paths block "$TOO_MANY"
fi

# De todas las reglas que matchean, en las dos políticas, gana la más estricta y, a igualdad,
# la del SDK: el consumidor añade protección, nunca la quita (SC-17, SC-18, SC-20)
eval_policy "$DEFAULT_POLICY"
d_id="$m_id"; d_mode="$m_mode"; d_reason="$m_reason"; d_policy="$m_policy"
c_id=""; c_mode=""; c_reason=""; c_policy=""
if [ -f "$POLICY" ]; then
  eval_policy "$POLICY"
  c_id="$m_id"; c_mode="$m_mode"; c_reason="$m_reason"; c_policy="$m_policy"
fi
if [ -n "$c_id" ] && [ "$(rank "$c_mode")" -gt "$(rank "$d_mode")" ]; then
  CUR_POLICY="$c_policy"; rule_matched "$c_id" "$c_mode" "$c_reason"
elif [ -n "$d_id" ]; then
  CUR_POLICY="$d_policy"; rule_matched "$d_id" "$d_mode" "$d_reason"
fi

# Ninguna regla matchea → pasa (SC-01)
exit 0
