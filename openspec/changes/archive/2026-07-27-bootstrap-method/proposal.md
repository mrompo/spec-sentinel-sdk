# Proposal — bootstrap-method (fase 0)

## Por qué

El plan v2 está cerrado (decisiones incluidas, plan §11) y el mayor riesgo ahora es seguir
planificando en vez de validar. Esta fase convierte el repo en el primer consumidor del método:
estructura mínima, OpenSpec operativo, KPIs definidos y un fixture donde toda regla del
framework pueda falsificarse.

## Qué cambia

1. **OpenSpec operativo** en el repo (config con spec-order-markers e ids de escenario,
   `project.md` como fuente transversal, este cambio como primero del historial).
2. **Esqueleto de la estructura** del plan §3: `docs/` (ya existe), `ai-specs/agents/`,
   `ai-specs/skills/`, `sentinel/{policy.yaml,hooks,githooks,ci,adapters}` (vacíos con README
   de contrato), symlinks multi-copilot (`CLAUDE.md`/`AGENTS.md`/`GEMINI.md`/`codex.md`).
3. **KPIs instrumentables** (plan §9): definición de cómo se captura cada uno desde los
   artefactos (timestamps de changes, log de overrides, salida de doctor/spec-coverage).
4. **Fixture base**: carpeta `fixture/` con un mini-repo de ejemplo y stub de workflow CI que
   lo ejercita — el banco de pruebas donde las fases 1+ demostrarán su DoD.
5. **README** actualizado: tiers, estado "fase 0 en marcha", roadmap v2.

## Qué NO cambia

Ningún hook ni gate se implementa aquí (eso es fase 1 `sentinel-guard`); no se vendoriza
ninguna skill (fase 4+); no hay perfil de stack todavía.

## Criterio de éxito (DoD)

El repo se desarrolla vía OpenSpec: la fase 1 arrancará como `changes/sentinel-guard/` y este
cambio quedará archivado con sus tareas completas.
