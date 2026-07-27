# Spec Sentinel SDK — Instrucciones para agentes

> Fuente única multi-copilot: `CLAUDE.md`, `GEMINI.md` y `codex.md` son symlinks a este
> fichero. Edita solo aquí.

## Antes de nada

1. Carga `openspec/project.md` (fuente de verdad transversal — OpenSpec no lo auto-inyecta).
2. Identifica el cambio OpenSpec activo en `openspec/changes/` y trabaja dentro de él.
   **Nada entra en `main` sin su cambio OpenSpec.**

## Reglas duras de este repo

- La spec es el contrato: el código se valida contra ella, no al revés.
- Conventional commits · sin force-push · sin `--no-verify`.
- Solo estructura/documentación hasta que la fase del roadmap lo pida (ver plan §10) —
  la lógica de enforcement llega en su fase, con su test en el fixture.
- El progreso real vive en el `tasks.md` del cambio activo: marca `- [x]` al completar.
- Toda regla dura que añadas debe poder falsificarse en `fixture/`.

## Mapa

Plan v2: `docs/01-plan-maestro.md` · Contratos: `sentinel/README.md`, `ai-specs/*/README.md`
· Política de guardarraíles: `sentinel/policy.yaml` · Banco de pruebas: `fixture/`
