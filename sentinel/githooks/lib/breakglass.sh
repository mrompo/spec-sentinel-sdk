#!/usr/bin/env bash
# breakglass.sh — la excepción auditada de la Esclusa. Se usa con `source` desde los hooks.
# Mismo contrato que el Centinela (sentinel/hooks/sentinel-guard.sh):
#   1) sentinel/.override con un motivo → llave de UN SOLO USO, se consume al aplicarse
#   2) SENTINEL_OVERRIDE con un motivo en el entorno → vale para toda la sesión
# Cada uso deja una línea en sentinel/overrides.log (fecha | esclusa:<hook> | qué | motivo). Si
# la bitácora no se puede escribir, no hay excepción y la llave se conserva.
# Falsifica: SC-git-gates-11, 12, 13 (fixture/githooks/cases/).

_bg_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

# _bg_reason → el motivo de la excepción, o exit 1 si no hay ninguna válida (vacío o solo
# espacios no vale)
_bg_reason() {
  local v
  if [ -n "$(printf '%s' "${SENTINEL_OVERRIDE:-}" | tr -d '[:space:]')" ]; then
    printf '%s' "$SENTINEL_OVERRIDE"; return 0
  fi
  local token; token="$(_bg_root)/sentinel/.override"
  if [ -f "$token" ]; then
    v="$(tr '\n' ' ' <"$token")"
    [ -n "$(printf '%s' "$v" | tr -d '[:space:]')" ] && { printf '%s' "$v"; return 0; }
  fi
  return 1
}

# esclusa_reject <hook> <qué se rechaza> → NO retorna. Con excepción válida: la registra, avisa y
# sale con 0. Sin ella (o sin bitácora escribible): sale con 1 y dice cómo pedir la excepción.
esclusa_reject() {
  local hook="$1" what="$2" root verb reason log token line
  root="$(_bg_root)"; log="$root/sentinel/overrides.log"; token="$root/sentinel/.override"
  case "$hook" in pre-push) verb="El push no se ha hecho" ;; *) verb="El commit no se ha creado" ;; esac

  if reason="$(_bg_reason)"; then
    line="$(printf '%s | esclusa:%s | %s | %s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$hook" \
      "$(printf '%s' "$what" | tr '\n' ' ')" "$(printf '%s' "$reason" | sed -e 's/[[:space:]]*$//')")"
    if mkdir -p "$(dirname "$log")" 2>/dev/null && printf '%s\n' "$line" >>"$log" 2>/dev/null; then
      [ -f "$token" ] && rm -f "$token"    # un solo uso: se consume DESPUÉS de registrar
      echo "⚠ [Esclusa] Excepción aplicada: rechazo permitido y auditado en sentinel/overrides.log — ${reason}" >&2
      exit 0
    fi
    echo "✗ [Esclusa] Excepción denegada: no se pudo escribir la bitácora ($log) — sin registro no hay excepción. La llave se conserva." >&2
    echo "$verb." >&2
    exit 1
  fi

  echo "$verb. Corrige lo anterior y vuelve a intentarlo." >&2
  echo "    (Excepción auditada: una persona escribe el motivo en sentinel/.override — un solo uso, queda en la bitácora.)" >&2
  exit 1
}
