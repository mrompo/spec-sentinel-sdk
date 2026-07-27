#!/usr/bin/env bash
# sentinel-guard — capa 2 del enforcement (PreToolUse).
# Contrato: stdin = JSON del tool call · exit 0 = pasa · exit 2 + stderr = denegado con motivo.
# Las reglas viven en sentinel/policy.yaml (un solo hook de política, decisión plan §11).
# Sin dependencias: bash + grep/sed. Override auditado: SENTINEL_OVERRIDE (slice 6).
set -uo pipefail

POLICY="${SENTINEL_POLICY:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)/sentinel/policy.yaml}"

deny() { echo "sentinel-guard: $1" >&2; exit 2; }

# ── Fail-closed (SC-sentinel-guard-02): sin política legible no se ejecuta nada ──────────
[ -f "$POLICY" ] \
  || deny "política no encontrada ($POLICY) — restaura sentinel/policy.yaml o exporta SENTINEL_POLICY"
grep -q '^version:' "$POLICY" && grep -q '^rules:' "$POLICY" \
  || deny "política ilegible ($POLICY): faltan las claves 'version:' y/o 'rules:' — revisa el fichero"

# ── Tool call por stdin ──────────────────────────────────────────────────────────────────
PAYLOAD="$(cat || true)"
[ -n "$PAYLOAD" ] || deny "sin payload: este hook espera el JSON del tool call por stdin"

# ── Evaluación de reglas (slices 3-6) ────────────────────────────────────────────────────
# Orden: primera regla que matchea decide. Aún sin reglas implementadas:
# acción sin regla que la cubra → pasa (SC-sentinel-guard-01).
exit 0
