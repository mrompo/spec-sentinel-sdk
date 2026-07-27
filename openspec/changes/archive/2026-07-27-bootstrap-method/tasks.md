# Tasks — bootstrap-method

> Epic card (patrón B): objetivo + contexto compartido + índice. El progreso real vive aquí
> (checklist); en conflicto con otros ficheros, gana este.

**Objetivo**: repo desarrollándose con su propio método (DoD del proposal).
**Restricción global**: solo estructura y documentación — cero lógica de hooks/gates (fase 1).

## Checklist

- [x] 1. `openspec/` operativo: `config.yaml` (spec-order-markers + ids SC-*) + `project.md`
- [x] 2. Cambio `bootstrap-method` creado (proposal + tasks + spec delta)
- [x] 3. Esqueleto `ai-specs/{agents,skills}/` con README de contrato (anatomía D, manifiesto de contexto)
- [x] 4. Esqueleto `sentinel/{hooks,githooks,ci,adapters}/` + `policy.yaml` de ejemplo comentado (sin lógica)
- [x] 5. Symlinks multi-copilot: `AGENTS.md` fuente única; `CLAUDE.md`/`GEMINI.md`/`codex.md` → symlinks
- [x] 6. `fixture/` base: `demo-app/` + `verify.sh` (en verde) + workflow `fixture.yml`
- [x] 7. KPIs instrumentables: `docs/04-kpis.md` con fórmula, fuente y fase de cada KPI
- [x] 8. README actualizado: tiers, estado fase 0, roadmap v2
- [x] 9. Revisión humana del paquete → `openspec validate --all --strict` en verde →
       archivado como `2026-07-27-bootstrap-method` (spec viva: `specs/sdk-method/`) →
       commit + merge a main

## Preguntas abiertas

- ~~¿El fixture dentro del repo o como repo hermano?~~ **Resuelta**: dentro (`fixture/`),
  hasta que el instalador `setup` exija probar instalación remota.
