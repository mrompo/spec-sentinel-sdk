#!/usr/bin/env bash
# sentinel-guard — capa 2 del enforcement (PreToolUse).
# Contrato: stdin = JSON del tool call · exit 0 = pasa · exit 2 + stderr = denegado con motivo.
# Las reglas viven en sentinel/policy.yaml (esquema v1, plano) — un solo hook de política.
# Sin dependencias: bash + grep/sed. Orden: la primera regla que matchea decide.
# Break-glass: SENTINEL_OVERRIDE="<motivo>" permite y registra en sentinel/overrides.log.
set -uo pipefail

POLICY="${SENTINEL_POLICY:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)/sentinel/policy.yaml}"

deny() { echo "sentinel-guard: $1" >&2; exit 2; }

# ── Fail-closed (SC-02): sin política legible no se ejecuta nada ─────────────────────────
[ -f "$POLICY" ] \
  || deny "política no encontrada ($POLICY) — restaura sentinel/policy.yaml o exporta SENTINEL_POLICY"
grep -q '^version:' "$POLICY" && grep -q '^rules:' "$POLICY" \
  || deny "política ilegible ($POLICY): faltan las claves 'version:' y/o 'rules:' — revisa el fichero"

# ── Contexto ─────────────────────────────────────────────────────────────────────────────
PAYLOAD="$(cat || true)"
[ -n "$PAYLOAD" ] || deny "sin payload: este hook espera el JSON del tool call por stdin"

TOOL_NAME="$(printf '%s' "$PAYLOAD" | sed -nE 's/.*"tool_name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1)"
FILE_PATH="$(printf '%s' "$PAYLOAD" | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1)"
COMMAND="$(printf '%s' "$PAYLOAD" | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
POLICY_SDD="$(sed -nE 's/^sdd:[[:space:]]*(true|false).*/\1/p' "$POLICY" | head -1)"
OVERRIDES_LOG="$(dirname "$POLICY")/overrides.log"

ACTIVE_CHANGE=""
if [ -d openspec/changes ]; then
  ACTIVE_CHANGE="$(find openspec/changes -mindepth 1 -maxdepth 1 -type d ! -name archive 2>/dev/null | head -1)"
fi

# ── Acciones por modo ────────────────────────────────────────────────────────────────────
log_override() { # regla que se salta con break-glass → registro auditado (SC-08)
  printf '%s | %s | %s | %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "${TOOL_NAME}:${COMMAND:-${FILE_PATH:-?}}" "$SENTINEL_OVERRIDE" \
    >> "$OVERRIDES_LOG"
}

rule_matched() { # $1=id $2=mode $3=reason — la primera regla que matchea decide y NO retorna
  local id="$1" mode="$2" reason="$3"
  case "$mode" in
    warn)
      echo "sentinel-guard[warn:$id]: $reason" >&2
      exit 0
      ;;
    block|confirm)
      if [ -n "${SENTINEL_OVERRIDE:-}" ]; then
        log_override "$id"
        echo "sentinel-guard[override:$id]: permitido con registro auditado — $SENTINEL_OVERRIDE" >&2
        exit 0
      fi
      if [ "$mode" = "confirm" ]; then
        [ "${SENTINEL_CONFIRM:-}" = "1" ] && exit 0
        deny "[$id] $reason — si un humano lo aprueba, relanza con SENTINEL_CONFIRM=1"
      fi
      deny "[$id] $reason (vía de emergencia auditada: SENTINEL_OVERRIDE=\"motivo\")"
      ;;
    *)
      deny "[$id] modo desconocido '$mode' en la política — corrige sentinel/policy.yaml"
      ;;
  esac
}

# ── Evaluación de una regla acumulada ────────────────────────────────────────────────────
reset_rule() { r_id=""; r_tool=""; r_command_re=""; r_path_re=""; r_content_re=""; r_branch_re=""; r_mode=""; r_reason=""; r_requires_sdd=""; r_no_active=""; }

apply_rule() {
  [ -n "$r_id" ] || return 0
  [ -n "$r_mode" ] || return 0
  if [ "$r_requires_sdd" = "true" ] && [ "$POLICY_SDD" != "true" ]; then return 0; fi
  if [ "$r_no_active" = "true" ] && [ -n "$ACTIVE_CHANGE" ]; then return 0; fi
  if [ -n "$r_tool" ]; then printf '%s' "$TOOL_NAME" | grep -qE "^($r_tool)$" || return 0; fi
  if [ -n "$r_command_re" ]; then
    [ -n "$COMMAND" ] || return 0
    printf '%s' "$COMMAND" | grep -qE "$r_command_re" || return 0
  fi
  if [ -n "$r_path_re" ]; then
    [ -n "$FILE_PATH" ] || return 0
    printf '%s' "$FILE_PATH" | grep -qE "$r_path_re" || return 0
  fi
  if [ -n "$r_content_re" ]; then printf '%s' "$PAYLOAD" | grep -qE "$r_content_re" || return 0; fi
  if [ -n "$r_branch_re" ]; then printf '%s' "$BRANCH" | grep -qE "$r_branch_re" || return 0; fi
  rule_matched "$r_id" "$r_mode" "$r_reason"   # no retorna
}

# ── Parser del esquema v1 (clave: valor por línea; "- id:" abre regla) ───────────────────
val() { printf '%s' "${1#*: }"; }

reset_rule
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    \#*|"") continue ;;
    *"- id:"*)               apply_rule; reset_rule; r_id="$(val "$line")" ;;
    *"tool:"*)               r_tool="$(val "$line")" ;;
    *"command_re:"*)         r_command_re="$(val "$line")" ;;
    *"path_re:"*)            r_path_re="$(val "$line")" ;;
    *"content_re:"*)         r_content_re="$(val "$line")" ;;
    *"branch_re:"*)          r_branch_re="$(val "$line")" ;;
    *"only_if_no_active_change:"*) r_no_active="$(val "$line")" ;;
    *"requires_sdd:"*)       r_requires_sdd="$(val "$line")" ;;
    *"mode:"*)               r_mode="$(val "$line")" ;;
    *"reason:"*)             r_reason="$(val "$line")" ;;
  esac
done < "$POLICY"
apply_rule

# Ninguna regla matchea → la acción pasa (SC-01)
exit 0
