# project.md — Spec Sentinel SDK (fuente de verdad transversal)

> Los agentes y skills deben cargar este fichero explícitamente — OpenSpec no lo auto-inyecta
> (lección de B). `doctor` validará que las referencias de aquí existan.

## Qué es

Framework portable de desarrollo asistido por IA con SDD (OpenSpec): convierte *reglas que el
agente debería seguir* en *reglas que el agente no puede violar*. Plan completo:
[`docs/01-plan-maestro.md`](../docs/01-plan-maestro.md) (v2). Se construye con su propio método:
**cada fase del roadmap = un cambio OpenSpec** en este directorio.

## Reglas duras (no negociables)

1. Nada entra en `main` sin su cambio OpenSpec (este repo es Tier 1 de sí mismo).
2. La spec es el contrato: el código se valida contra ella, no al revés.
3. Conventional commits; sin force-push; sin `--no-verify`.
4. Toda regla dura del framework tiene un test que la falsifica (fixture, fase 0+).
5. Todo gate tiene break-glass auditado (desde fase 1).
6. Vendor, no reescribir: lo que D/Boost/OpenSpec mantienen, se vendoriza con `skills-lock.json`.

## Mapa

- Visión: `docs/framework-contex.md` · Plan v2: `docs/01-plan-maestro.md`
- Investigación (repo hermano, no versionada aquí): `../spec-sentinel-research/` —
  00 (fuentes A/B/C) · 02 (D·Osmani) · 03 (gitflow B)
- Estructura objetivo del SDK: plan §3 · Equipo: §4 · Skills: §5 · Guardarraíles: §6
- Estado actual (roadmap + ciclo): **`STATUS.md`** en la raíz — se actualiza al abrir y al
  archivar cada cambio (desde fase 4 lo generará `doctor --status`).
- Convención de proposals: cabeceras `## Why` y `## What Changes` (las espera `openspec validate`).
- Convención de cierre de fase: antes de archivar, actualizar `STATUS.md` **y** la sección
  correspondiente de `docs/guia-uso.md` (la guía crece con cada fase, en lenguaje simple).
