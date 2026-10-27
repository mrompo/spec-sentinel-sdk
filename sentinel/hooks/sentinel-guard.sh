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
NORM_PATH=""
if [ -n "$FILE_PATH" ]; then
  case "$FILE_PATH" in /*) NORM_PATH="$FILE_PATH" ;; *) NORM_PATH="$PWD/$FILE_PATH" ;; esac
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
GIT_COMMON_PHYS=""
_gcd="$(git rev-parse --git-common-dir 2>/dev/null)" && GIT_COMMON_PHYS="$(phys_dir "$_gcd")"
CLAUDE_CFG="${CLAUDE_CONFIG_DIR:-${HOME:-/nonexistent}/.claude}"
CLAUDE_CFG_PHYS="$(phys_dir "$CLAUDE_CFG")"

canon() { # $1=ruta física → cómo la nombra la política
  local p="$1"
  if [ -n "$GIT_COMMON_PHYS" ]; then
    case "$p" in "$GIT_COMMON_PHYS"|"$GIT_COMMON_PHYS"/*) printf '.git%s' "${p#"$GIT_COMMON_PHYS"}"; return ;; esac
  fi
  if [ -n "$CLAUDE_CFG_PHYS" ]; then
    case "$p" in "$CLAUDE_CFG_PHYS"|"$CLAUDE_CFG_PHYS"/*) printf '.claude%s' "${p#"$CLAUDE_CFG_PHYS"}"; return ;; esac
  fi
  case "$p" in
    "$REPO_PHYS") printf '.' ;;
    "$REPO_PHYS"/*) printf '%s' "${p#"$REPO_PHYS"/}" ;;
    *) printf '%s' "$p" ;;
  esac
}

TOUCHED=""   # ruta física de cada cosa que toca la acción, tal como la nombra la política
PHYS_ALL=""  # y su ruta física absoluta
add_target() { # $1=ruta absoluta
  local ph; ph="$(phys_path "$1")"
  TOUCHED="$TOUCHED
$(canon "$ph")"
  PHYS_ALL="$PHYS_ALL
$ph"
}
[ -n "$NORM_PATH" ] && add_target "$NORM_PATH"
if [ -n "$COMMAND" ]; then
  # Palabras del comando: sin comillas, separadores ni escapes JSON; '=' también separa
  # (--file=x, include.path=x). Cuenta como ruta la que lleva '/' o existe.
  _words="$(printf '%s' "$COMMAND" | sed -e 's/\\[nt"]/ /g' -e "s/[\"'\`;|&<>()=]/ /g")"
  set -f; _n=0
  for w in $_words; do
    case "$w" in -*) continue ;; esac
    case "$w" in
      "~"|"~/"*) w="${HOME:-}${w#"~"}" ;;
      '$HOME'|'$HOME/'*) w="${HOME:-}${w#'$HOME'}" ;;
      '${HOME}'|'${HOME}/'*) w="${HOME:-}${w#'${HOME}'}" ;;
      '$CLAUDE_CONFIG_DIR'|'$CLAUDE_CONFIG_DIR/'*) w="$CLAUDE_CFG${w#'$CLAUDE_CONFIG_DIR'}" ;;
      '${CLAUDE_CONFIG_DIR}'|'${CLAUDE_CONFIG_DIR}/'*) w="$CLAUDE_CFG${w#'${CLAUDE_CONFIG_DIR}'}" ;;
    esac
    case "$w" in */*) ;; *) { [ -e "$w" ] || [ -L "$w" ]; } || continue ;; esac
    case "$w" in /*) ;; *) w="$PWD/$w" ;; esac
    while :; do
      case "$w" in /) break ;; */) w="${w%/}" ;; */.) w="${w%/.}" ;; *) break ;; esac
    done
    add_target "$w"
    _n=$((_n+1)); [ "$_n" -lt 64 ] || break
  done
  set +f
fi

# Superficie de rutas: relativa al repo + absoluta + comando (un shell toca ficheros sin
# file_path) + la ruta física de lo que se toca, nombrada como la política y absoluta
PATH_SURFACE="$REL_PATH
$FILE_PATH
$COMMAND$TOUCHED$PHYS_ALL"

ACTIVE_CHANGE=""
if [ -d "$REPO_ROOT_DIR/openspec/changes" ]; then
  ACTIVE_CHANGE="$(find "$REPO_ROOT_DIR/openspec/changes" -mindepth 1 -maxdepth 1 -type d ! -name archive 2>/dev/null | head -1)"
fi

ACTION_DESC="${TOOL_NAME}:${COMMAND:-${REL_PATH:-$FILE_PATH}}"

# ── Break-glass auditado ─────────────────────────────────────────────────────────────────
# Dos vías, ambas fuera del alcance del agente (la política protege sentinel/**):
#   1) SENTINEL_OVERRIDE exportado en el entorno de la sesión (afecta a la sesión entera)
#   2) sentinel/.override con el motivo → token de UN SOLO USO, se consume al aplicarse
override_reason() {
  if [ -n "${SENTINEL_OVERRIDE:-}" ] && [ -n "$(printf '%s' "$SENTINEL_OVERRIDE" | tr -d '[:space:]')" ]; then
    printf '%s' "$SENTINEL_OVERRIDE"; return 0
  fi
  if [ -s "$OVERRIDE_TOKEN" ]; then
    tr -d '\n' < "$OVERRIDE_TOKEN"; return 0
  fi
  return 1
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
      deny "[$id] $reason (excepción auditada: pide a un humano 'echo \"motivo\" > sentinel/.override')"
      ;;
    *)
      deny "[$id] modo desconocido '$mode' en la política — corrige $CUR_POLICY"
      ;;
  esac
}

# ── Evaluación de reglas ─────────────────────────────────────────────────────────────────
reset_rule() { r_id=""; r_tool=""; r_command_re=""; r_path_re=""; r_dir_re=""; r_content_re=""; r_branch_re=""; r_mode=""; r_reason=""; r_requires_sdd=""; r_no_active=""; }

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
    match "$COMMAND" "$r_command_re" || return 1
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
        elif kv "$line" "mode";                     then r_mode="$(val "$line")"
        elif kv "$line" "reason";                   then r_reason="$(val "$line")"
        fi ;;
    esac
  done < "$1"
  apply_rule || true
}

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
