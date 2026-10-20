# Proposal — sdk-version (qué versión del SDK está instalada, y no retroceder sin querer)

> Nace de la tercera revisión adversarial de `git-gates` (P3-4,
> [`../git-gates/review/round3/README.md`](../git-gates/review/round3/README.md)). La persona
> decidió el 2026-10-17 sacarlo de esa PR a su propio cambio.

## Why

`setup` instala lo que haya en la copia del SDK desde la que se ejecuta, sin saber qué versión
había instalada en el repo. La revisión lo reprodujo: un compañero con un clon del SDK tres
commits más viejo, al que `session-start` le dice «ejecuta setup», revierte el enforcement en
silencio (la regla `protect-installer` y la de «gana la más estricta» desaparecen) y `setup` le
invita a commitearlo con «✓ Nivel Guardia instalado». En el repo nada dice qué versión del SDK
está instalada, así que la bajada solo se ve leyendo el diff de `sentinel/`.

## What Changes

1. `setup` escribe un fichero versionado (p. ej. `sentinel/.sdk-version`) con la versión del SDK
   que instala: el tag o el commit, y si su árbol tenía cambios sin commitear.
2. Antes de sustituir lo distribuido, `setup` compara esa versión con la del SDK desde el que se
   ejecuta: si es más antigua o el árbol está sucio, no sustituye nada sin una confirmación
   explícita de la persona, y dice qué haría.
3. En un clon que ya tiene `sentinel/` versionado, `session-start` y la guía indican solo
   activar `core.hooksPath` (o un modo de `setup` que active sin copiar), en vez de «ejecuta
   setup».

## Impact

- Capability afectada: `sdk-setup` (y el aviso de `session-start` en `sentinel-guard`).
- Ficheros: `ai-specs/skills/setup/setup.sh` y `sentinel/hooks/session-start.sh` (protegidos: los
  aplica una persona o con la llave).
- El banco gana casos con un SDK más viejo, uno con cambios sin commitear y un clon que ya
  tiene la instalación versionada.
