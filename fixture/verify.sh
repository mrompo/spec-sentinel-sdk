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
    grep -q "$term" "$SEM" || err "la semántica no define «$term»"
  done
  ok "semántica: modelo, stages, steps y puestos definidos"
  for doc in README.md docs/guia-uso.md; do
    grep -qE '(Engine|Shield|Tribunal|Delivery)' "$doc" && grep -qiE '(stage|loop)' "$doc" \
      && ok "$doc usa el vocabulario" \
      || err "$doc no usa el vocabulario del framework (ver docs/05-semantica.md)"
  done
else
  err "falta docs/05-semantica.md (fuente única del vocabulario)"
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
