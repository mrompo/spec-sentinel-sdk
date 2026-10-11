#!/usr/bin/env bash
# setup.sh — instala el nivel Guardia (Centinela + Esclusa) en un repo con un solo comando.
#
#   bash <sdk>/ai-specs/skills/setup/setup.sh [raíz-del-repo]      (por defecto, el directorio actual)
#
# Lo invoca la skill `setup` (SKILL.md, al lado); también se puede ejecutar a mano. Idempotente:
# una segunda ejecución no cambia nada. Nunca pisa la configuración del consumidor:
#   - lo distribuido (hooks, githooks, lector del adaptador) se instala o actualiza, con backup si
#     el fichero del consumidor difería;
#   - lo del consumidor (policy.yaml, overrides.log, stack.yaml) solo se crea si no existe;
#   - .claude/settings.json se fusiona con jq; sin jq, o si la fusión no es segura, se deja
#     sentinel/settings.fragment.json y se explica el paso manual;
#   - core.hooksPath solo se activa si el repo no usa ya otros git hooks.
# Los backups van a sentinel/.backup/<fecha>/ (fuera de git).
#
# Salida: 0 instalado · 3 instalado con pasos pendientes (se listan) · 1 error, nada a medias.
# Variables: SENTINEL_SETUP_JQ (binario de jq), SENTINEL_GITLEAKS_BIN (el mismo que la Esclusa).
# Falsifica: SC-sdk-setup-01..08 (fixture/install/cases/).
set -uo pipefail

SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
JQ="${SENTINEL_SETUP_JQ:-jq}"
GITLEAKS="${SENTINEL_GITLEAKS_BIN:-gitleaks}"
HOOKS_PATH="sentinel/githooks"

pending=0
die()  { echo "✗ [setup] $1" >&2; exit 1; }
ok()   { echo "✓ $1"; }
note() { echo "· $1"; }
todo() { echo "⚠ PENDIENTE: $1"; pending=1; }

# ── Comprobaciones: nada se escribe hasta que todo cuadra ────────────────────────────────
[ -f "$SDK_ROOT/sentinel/hooks/sentinel-guard.sh" ] && [ -f "$SDK_ROOT/sentinel/policy.yaml" ] \
  || die "SDK incompleto en $SDK_ROOT: falta sentinel/ — ejecuta setup.sh desde una copia íntegra del SDK"
[ -d "${1:-.}" ] || die "no existe el directorio ${1:-.}"
TARGET="$(cd "${1:-.}" && pwd -P)"
TOP="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" \
  || die "$TARGET no es un repo git — inicialízalo (git init) y vuelve a ejecutar setup"
# Solo en la raíz: dentro de un subdirectorio, la instalación caería en otro sitio (o en un repo padre)
[ "$(cd "$TOP" && pwd -P)" = "$TARGET" ] \
  || die "$TARGET no es la raíz del repo — ejecuta setup en $TOP"
SELF=0; [ "$TARGET" = "$SDK_ROOT" ] && SELF=1

STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
backup() {
  local rel="$1" dir="$TARGET/sentinel/.backup/$STAMP"
  mkdir -p "$dir/$(dirname "$rel")" && cp -p "$TARGET/$rel" "$dir/$rel" \
    || die "no se pudo hacer backup de $rel — no se toca nada más"
  note "backup de $rel en sentinel/.backup/$STAMP/"
}

echo "Instalando el nivel Guardia en $TARGET"

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
  done < <(cd "$SDK_ROOT" && find sentinel/README.md sentinel/hooks sentinel/githooks sentinel/adapters \
             -type f ! -name '.*' ! -name stack.yaml ! -name stack.proposed.yaml | LC_ALL=C sort)
  [ "$updated" -gt 0 ] && ok "enforcement instalado o actualizado ($updated ficheros en sentinel/)" \
    || ok "enforcement al día"
fi

# ── 2. Lo del consumidor (solo se crea si falta) ─────────────────────────────────────────
# TODO slice 6: con la política separada, aquí se actualizará policy.default.yaml y policy.yaml
# quedará solo para las reglas propias del consumidor (SC-sdk-setup-05).
if [ -f "$TARGET/sentinel/policy.yaml" ]; then
  ok "política del consumidor conservada (sentinel/policy.yaml)"
else
  cp "$SDK_ROOT/sentinel/policy.yaml" "$TARGET/sentinel/policy.yaml" || die "no se pudo crear la política"
  ok "política creada (sentinel/policy.yaml) — es tuya: adáptala en un cambio revisado"
fi
[ -f "$TARGET/sentinel/overrides.log" ] || { : >"$TARGET/sentinel/overrides.log" && ok "bitácora creada (sentinel/overrides.log)"; }

# .gitignore: la llave nunca se versiona; los backups tampoco
GI="$TARGET/.gitignore"; gi_added=""
for line in "sentinel/.override" "sentinel/.backup/"; do
  [ -f "$GI" ] && grep -qxF "$line" "$GI" && continue
  [ -s "$GI" ] && [ -n "$(tail -c1 "$GI")" ] && echo >>"$GI"
  echo "$line" >>"$GI"; gi_added="$gi_added $line"
done
[ -n "$gi_added" ] && ok ".gitignore:$gi_added"

# ── 3. Cableado del Centinela en .claude/settings.json ───────────────────────────────────
FRAGMENT='{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write|MultiEdit|NotebookEdit|Read|Grep|Glob",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/sentinel/hooks/sentinel-guard.sh\"" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/sentinel/hooks/post-edit.sh\"" }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/sentinel/hooks/session-start.sh\"" }
        ]
      }
    ]
  }
}'
# Fusión conservadora: por cada evento, se añaden las entradas del SDK cuyo comando no esté ya
SAFE='type == "object" and ((.hooks // {}) | type == "object")
      and ([(.hooks // {})[] | type == "array"] | all)'
MERGE='reduce ($frag.hooks | to_entries[]) as $e (.;
         (.hooks[$e.key] // []) as $cur
         | .hooks[$e.key] = $cur + [ $e.value[]
             | select(.hooks[0].command as $c | any($cur[]?.hooks[]?.command; . == $c) | not) ])'

S="$TARGET/.claude/settings.json"; F="$TARGET/sentinel/settings.fragment.json"
write_fragment() {
  [ -f "$F" ] && [ "$(cat "$F")" = "$FRAGMENT" ] || printf '%s\n' "$FRAGMENT" >"$F"
  todo "$1 — .claude/settings.json no se ha tocado. Añade a mano las entradas de
    sentinel/settings.fragment.json dentro de \"hooks\" (o instala jq y vuelve a ejecutar setup)"
}
if [ ! -f "$S" ]; then
  mkdir -p "$TARGET/.claude" && printf '%s\n' "$FRAGMENT" >"$S" || die "no se pudo crear .claude/settings.json"
  ok "Centinela cableado (.claude/settings.json creado)"
elif ! command -v "$JQ" >/dev/null 2>&1; then
  write_fragment "jq no está instalado y ya hay un .claude/settings.json"
elif ! "$JQ" -e "$SAFE" "$S" >/dev/null 2>&1; then
  write_fragment ".claude/settings.json no es JSON válido o tiene una forma inesperada: fusionar no es seguro"
else
  merged="$("$JQ" --argjson frag "$FRAGMENT" "$MERGE" "$S")" || die "jq falló al fusionar .claude/settings.json"
  if [ "$("$JQ" -S . "$S")" = "$(printf '%s' "$merged" | "$JQ" -S .)" ]; then
    ok "Centinela ya cableado en .claude/settings.json"
  else
    backup ".claude/settings.json"
    printf '%s\n' "$merged" >"$S" || die "no se pudo escribir .claude/settings.json"
    ok "Centinela cableado: entradas del SDK añadidas a .claude/settings.json (lo tuyo se conserva)"
  fi
fi

# ── 4. La Esclusa: core.hooksPath ────────────────────────────────────────────────────────
cur="$(git -C "$TARGET" config --get core.hooksPath || true)"
if [ "$cur" = "$HOOKS_PATH" ]; then
  ok "Esclusa activa (core.hooksPath → $HOOKS_PATH)"
elif [ -n "$cur" ]; then
  # Puede venir del config global de la persona (p. ej. un escáner corporativo): tampoco se pisa
  origin="$(git -C "$TARGET" config --show-origin --get core.hooksPath 2>/dev/null | cut -f1)"
  todo "el repo ya usa core.hooksPath → «${cur}» (definido en ${origin:-config de git}); no se
    cambia para no silenciar esos hooks.
    Encadena la Esclusa: al final de cada hook de «${cur}» (commit-msg, pre-commit, pre-push) añade
    «$HOOKS_PATH/<hook> \"\$@\" || exit 1» — o, si ya no los necesitas: git config core.hooksPath $HOOKS_PATH"
else
  hd="$(git -C "$TARGET" rev-parse --git-path hooks)"
  case "$hd" in /*) ;; *) hd="$TARGET/$hd" ;; esac
  own=""
  for h in "$hd"/*; do
    [ -f "$h" ] && [ -x "$h" ] && case "$h" in *.sample) ;; *) own="$own $(basename "$h")" ;; esac
  done
  if [ -n "$own" ]; then
    todo "hay git hooks propios en $hd:$own. Activar la Esclusa (core.hooksPath) los dejaría
    sin ejecutarse, así que no se activa. Muévelos a $HOOKS_PATH encadenados con los de la Esclusa,
    o llama a la Esclusa desde ellos, y después: git config core.hooksPath $HOOKS_PATH"
  else
    git -C "$TARGET" config core.hooksPath "$HOOKS_PATH" || die "no se pudo configurar core.hooksPath"
    ok "Esclusa activada (core.hooksPath → $HOOKS_PATH)"
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
    [ -f "$A/stack.proposed.yaml" ] && [ "$(cat "$A/stack.proposed.yaml")" = "$proposal" ] \
      || printf '%s\n' "$proposal" >"$A/stack.proposed.yaml"
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

echo
if [ "$pending" -eq 1 ]; then
  echo "Nivel Guardia instalado con pasos pendientes (⚠ arriba). Vuelve a ejecutar setup al resolverlos."
  exit 3
fi
echo "✓ Nivel Guardia instalado. Versiona sentinel/, .claude/settings.json y .gitignore en un commit."
exit 0
