#!/usr/bin/env bash
# fixture/verify.sh — checks de fase 0 (bootstrap-method)
# Falsifica: SC-sdk-method-01 (cambio activo bien formado), SC-sdk-method-03/04 (symlinks).
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
err() { echo "✗ $1" >&2; fail=1; }
ok()  { echo "✓ $1"; }

# Estructura §3 del plan
for d in docs ai-specs/agents ai-specs/skills sentinel/hooks sentinel/githooks sentinel/ci sentinel/adapters openspec/changes fixture; do
  [ -d "$d" ] && ok "dir $d" || err "falta el directorio $d"
done
[ -f sentinel/policy.yaml ] && ok "sentinel/policy.yaml" || err "falta sentinel/policy.yaml"
[ -f openspec/project.md ] && ok "openspec/project.md" || err "falta openspec/project.md"

# Symlinks multi-copilot → fuente única (SC-sdk-method-03/04)
for f in CLAUDE.md GEMINI.md codex.md; do
  if [ -L "$f" ] && [ "$(readlink "$f")" = "AGENTS.md" ] && [ -e "$f" ]; then
    ok "symlink $f → AGENTS.md"
  else
    err "$f debe ser un symlink resoluble a AGENTS.md"
  fi
done

# Cambios OpenSpec activos bien formados (SC-sdk-method-01).
# Cero cambios activos es legítimo entre fases; los que existan deben estar completos.
active=$(find openspec/changes -mindepth 1 -maxdepth 1 -type d ! -name archive)
if [ -z "$active" ]; then
  ok "sin cambio activo (entre fases)"
else
  for c in $active; do
    for f in proposal.md tasks.md; do
      [ -f "$c/$f" ] && ok "$c/$f" || err "falta $c/$f"
    done
    ls "$c"/specs/*/spec.md >/dev/null 2>&1 && ok "$c/specs/*/spec.md" || err "falta delta spec en $c"
  done
fi

# Ids de escenario estables (regla de openspec/config.yaml), en cambios activos y specs vivas
if grep -rh "#### Scenario:" openspec/changes/*/specs/*/spec.md openspec/specs/*/spec.md 2>/dev/null | grep -qv "SC-"; then
  err "hay Scenarios sin id estable SC-*"
else
  ok "todos los Scenarios llevan id SC-*"
fi

# Semántica: el vocabulario está definido y las superficies lo usan (SC-framework-semantics-01/03)
SEM=docs/05-semantica.md
if [ -f "$SEM" ]; then
  for term in Loop Stage Step Gate Engine Shield Tribunal Delivery Canon Centinela Esclusa Aduana tune; do
    grep -q "$term" "$SEM" || err "la semántica no define «${term}»"
  done
  for slug in canon guard lock customs; do
    grep -q "(\`$slug\`)" "$SEM" || err "la semántica no da el slug «${slug}» de su puesto"
  done
  ok "semántica: modelo, stages, steps, puestos y slugs definidos"
  # Todo gate de salida de un step tiene camino de vuelta (SC-framework-semantics-07)
  RET=$(sed -n '/^### Los caminos de vuelta/,/^## 5\./p' "$SEM")
  GATES=$(sed -n '/^## 4\./,/^### Los caminos de vuelta/p' "$SEM" | grep '^| `' \
    | awk -F'|' '{print $(NF-1)}' | sed -n 's/^ *\*\*\([^*]*\)\*\*.*/\1/p')
  [ -n "$GATES" ] || err "semántica: no se encontraron gates en las tablas de steps (§4)"
  MISSING=$(echo "$GATES" | while IFS= read -r g; do
    echo "$RET" | grep -qF "| **$g" || echo "$g"; done)
  [ -z "$MISSING" ] && ok "semántica: todos los gates tienen camino de vuelta" \
    || err "gates sin camino de vuelta: $(echo "$MISSING" | tr '\n' ' ')"
  for doc in README.md docs/guia-uso.md; do
    grep -qE '(Engine|Shield|Tribunal|Delivery)' "$doc" && grep -qiE '(stage|loop)' "$doc" \
      && ok "$doc usa el vocabulario" \
      || err "$doc no usa el vocabulario del framework (ver docs/05-semantica.md)"
  done
else
  err "falta docs/05-semantica.md (fuente única del vocabulario)"
fi

# Formato de PR: la plantilla tiene las diez secciones, en orden (SC-pr-format-02)
TPL=.github/pull_request_template.md
if [ -f "$TPL" ]; then
  prev=0; n=0; tplbad=0
  for sec in "Expediente" "Posición en el Loop" "Qué cambia y por qué" "Escenarios" \
             "Qué NO cambia" "Verificación" "Riesgos y vuelta atrás" "Excepciones y deuda" \
             "Procedencia" "Foco de la revisión"; do
    n=$((n + 1))
    line=$(grep -nxF "## ${n}. ${sec}" "$TPL" | head -1 | cut -d: -f1 || true)
    if [ -z "$line" ]; then
      err "la plantilla de PR no tiene la sección «## ${n}. ${sec}»"; tplbad=1
    elif [ "$line" -le "$prev" ]; then
      err "la plantilla de PR tiene «${sec}» fuera de orden"; tplbad=1
    else
      prev=$line
    fi
  done
  [ "$tplbad" -eq 0 ] && ok "plantilla de PR: diez secciones en orden"
else
  err "falta $TPL (formato de PR, ver openspec pr-format)"
fi

# Runner de hooks: si el guard existe, sus casos son obligatorios (nunca skip silencioso)
if [ -f sentinel/hooks/sentinel-guard.sh ]; then
  if [ -d fixture/hooks/cases ] && ls fixture/hooks/cases/*.sh >/dev/null 2>&1; then
    bash fixture/hooks/run.sh || fail=1
  else
    err "existe sentinel-guard.sh pero no hay casos en fixture/hooks/cases — sin test, la regla no entra"
  fi
fi

[ "$fail" -eq 0 ] && echo "— fixture: OK" || { echo "— fixture: FALLOS" >&2; exit 1; }
