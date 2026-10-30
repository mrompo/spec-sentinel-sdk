#!/usr/bin/env bash
# breakglass.sh — la excepción auditada de la Esclusa. Se usa con `source` desde los hooks.
# Mismo contrato que el Centinela (sentinel/hooks/sentinel-guard.sh):
#   1) sentinel/.override con un motivo y `para: esclusa:<hook>` → llave de UN SOLO USO, que
#      solo gasta el rechazo de ese hook; se consume al aplicarse (sentinel-paths)
#   2) SENTINEL_OVERRIDE con un motivo en el entorno → vale para toda la sesión
# Cada uso deja una línea en sentinel/overrides.log (fecha | esclusa:<hook> | qué | motivo). Si
# la bitácora no se puede escribir, no hay excepción y la llave se conserva.
# Falsifica: SC-git-gates-11, 12, 13 (fixture/githooks/cases/).

_bg_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }
# _bg_quote <texto> → el texto entre comillas simples, tal que una shell lo lee igual
_bg_quote() { local q="'\\''"; printf "'%s'" "${1//\'/$q}"; }

# La llave: el motivo (las líneas que no son para:) y la acción que autoriza (para:)
_bg_para()   { sed -nE 's/^[[:space:]]*para:[[:space:]]*//p' "$1" 2>/dev/null | head -1 | sed -E 's/[[:space:]]+$//'; }
_bg_motivo() { grep -vE '^[[:space:]]*para:' "$1" 2>/dev/null | tr '\n' ' ' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }

# _bg_reason <hook> → el motivo de la excepción, o exit 1 si no hay ninguna válida para ese hook
# (vacío o solo espacios no vale; una llave sin para: o atada a otra acción tampoco)
_bg_reason() {
  local v token
  if [ -n "$(printf '%s' "${SENTINEL_OVERRIDE:-}" | tr -d '[:space:]')" ]; then
    printf '%s' "$SENTINEL_OVERRIDE"; return 0
  fi
  token="$(_bg_root)/sentinel/.override"
  [ -f "$token" ] || return 1
  v="$(_bg_motivo "$token")"
  [ -n "$v" ] && [ "$(_bg_para "$token")" = "esclusa:$1" ] || return 1
  printf '%s' "$v"
}

# esclusa_reject <hook> <qué se rechaza> → NO retorna. Con excepción válida: la registra, avisa y
# sale con 0. Sin ella (o sin bitácora escribible): sale con 1 y dice cómo pedir la excepción.
esclusa_reject() {
  local hook="$1" what="$2" root verb reason log token line
  root="$(_bg_root)"; log="$root/sentinel/overrides.log"; token="$root/sentinel/.override"
  case "$hook" in pre-push) verb="El push no se ha hecho" ;; *) verb="El commit no se ha creado" ;; esac

  if reason="$(_bg_reason "$hook")"; then
    line="$(printf '%s | esclusa:%s | %s | %s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$hook" \
      "$(printf '%s' "$what" | tr '\n' ' ')" "$(printf '%s' "$reason" | sed -e 's/[[:space:]]*$//')")"
    if mkdir -p "$(dirname "$log")" 2>/dev/null && printf '%s\n' "$line" >>"$log" 2>/dev/null; then
      # Un solo uso: se consume DESPUÉS de registrar, y solo si la excepción salió de la llave
      # (con SENTINEL_OVERRIDE, una llave para otra acción se conserva: sentinel-paths, V4)
      if [ -z "$(printf '%s' "${SENTINEL_OVERRIDE:-}" | tr -d '[:space:]')" ]; then
        [ -f "$token" ] && rm -f "$token"
      fi
      echo "⚠ [Esclusa] Excepción aplicada: rechazo permitido y auditado en sentinel/overrides.log — ${reason}" >&2
      exit 0
    fi
    echo "✗ [Esclusa] Excepción denegada: no se pudo escribir la bitácora ($log) — sin registro no hay excepción. La llave se conserva." >&2
    echo "$verb." >&2
    exit 1
  fi

  echo "$verb. Corrige lo anterior y vuelve a intentarlo." >&2
  if [ -s "$token" ]; then
    echo "    (La llave de sentinel/.override no vale para este rechazo — le falta el motivo o el para:, o es para otra acción ($(_bg_para "$token")) — y se conserva.)" >&2
  fi
  # Sin sangría: pegada tal cual en una shell, la línea LLAVE cierra el heredoc (sentinel-paths,
  # P4 = A6); con la ruta absoluta de la llave, pegada desde cualquier carpeta va a la raíz del
  # repo (revisión de la #18)
  echo "    (Excepción auditada: una persona, desde su terminal, escribe la llave de este hook — un solo uso," >&2
  echo "    queda en la bitácora. Copia estas cuatro líneas tal cual y pon el motivo:)" >&2
  echo "cat > $(_bg_quote "$token") <<'LLAVE'" >&2
  echo "<motivo>" >&2
  echo "para: esclusa:$hook" >&2
  echo "LLAVE" >&2
  exit 1
}
