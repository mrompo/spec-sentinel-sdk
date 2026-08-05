# Proposal — sentinel-guard (fase 1 · Tier 0)

## Why

Hoy `sentinel/policy.yaml` es un contrato comentado: describe qué no puede hacer el agente,
pero nada lo hace cumplir. Esta fase es "la joya" del roadmap (máximo valor, mínimo coste):
convierte la capa 2 en real — el agente pasa de *debería* a *no puede* — e inaugura el primer
KPI del framework (overrides de break-glass).

## What Changes

1. **`sentinel/hooks/sentinel-guard.sh`** (PreToolUse): lee el tool call (JSON por stdin, sin
   dependencias), evalúa `policy.yaml` regla a regla y decide: `block` (exit 2 + motivo por
   stderr), `confirm` (la acción no se ejecuta sin aprobación humana explícita), `warn`
   (pasa con aviso). Política ausente/corrupta = **fail-closed** con mensaje de arreglo.
2. **Break-glass auditado**: `SENTINEL_OVERRIDE=<motivo>` permite la acción y registra
   `timestamp · regla · acción · motivo` en `sentinel/overrides.log` (versionado). Sin motivo
   no hay override.
3. **Tier-awareness**: las reglas `requires_sdd` solo aplican con `tiers.sdd: true`.
4. **`session-start.sh`** (inyecta rama + cambio OpenSpec activo) y **`post-edit.sh`**
   (autoformato vía adaptador de stack, con degradación silenciosa).
5. **Cableado** en `.claude/settings.json` de este repo (el SDK se protege a sí mismo desde
   ya) e instalación en duoclaude (DoD de la fase).
6. **Fixture**: runner de hooks que simula tool calls + un caso por regla — cada regla de la
   política queda falsificada, incluido el override.

## Impact

- Nuevos: `sentinel/hooks/*.sh`, `sentinel/overrides.log`, `fixture/hooks/*`, `.claude/settings.json`.
- Modificados: `sentinel/policy.yaml` (si el diseño lo exige), `fixture/verify.sh`, `STATUS.md`.
- A partir del merge, los commits directos a `main` y las ediciones de specs archivadas quedan
  bloqueados también para humanos que usen el agente — el break-glass es la vía de escape.
