# Revisión adversarial, ronda 3 — `git-gates` PR 3/3 (instalación)

**Fecha**: 2026-10-17 · **Rama**: `feature/git-gates-install` (contenido de `e9725f5`, el S5 de la
ronda 3) · Mismo método que las rondas anteriores: tres lentes nuevas con contexto limpio,
`counter-review` cruzado y veredicto con [`../synthesis.sh`](../synthesis.sh). Fuera de alcance,
por decisión de la persona: el tema 4 de la ronda 2 (convivencia con otros gestores de hooks,
cambio [`hook-coexistence`](../../../hook-coexistence/proposal.md)) y el límite «regex evadibles».

## La ronda 2

Resueltos: lo que hay que versionar (`lib/`, `core.fileMode`, `.claude/` del `excludesFile`),
la regla más estricta en todas partes, el fragmento protegido, el conteo del cableado y `~` en
`core.hooksPath`. Siguen abiertos, más estrechos: la comprobación del cableado (A4) y la ruta del
enlace de la skill (A2-5 / V2-5).

## Veredicto: `HOLD`

Los 20 hallazgos están validados por las tres lentes. Agrupados por defecto:

| # | Defecto | Hallazgos | Severidad |
|---|---|---|---|
| 1 | La comprobación del cableado no sigue la semántica de JSON: con claves repetidas (también al pegar el fragmento a mano, sin jq), un `\u` en una clave o basura tras el objeto, `setup` da por cableado un Centinela que Claude Code no carga. Y no mira `disableAllHooks` | A3-prev-A2-prevA4 = P3-1, A3-1 | 🛑 bloqueante |
| 2 | Por el enlace de la skill que recomienda la guía (`~/.claude/skills/setup`), el instalador se edita sin bloqueo y se ejecuta sin aprobación | P3-2 = A3-prev-A2-5 | 🛑 bloqueante |
| 3 | La spec SC-sentinel-guard-13 promete cubrir variantes que la persona decidió dejar como límite | A3-prev-V2-6 | grave |
| 4 | `AGENTS.md` está protegido en la política distribuida: en cada consumidor el agente no puede editar el suyo | P3-3 | grave |
| 5 | `setup` no registra la versión del SDK: reinstalar desde un SDK viejo revierte el enforcement sin aviso | P3-4 | grave |
| 6 | Textos y detalles: los README describen la regla anterior y conteos viejos; el `git add` de la skill choca con el Centinela; la excepción de `.claude/` es demasiado amplia; el parser no recorta comentarios en línea; la prueba de humo no cubre todas las tools; un `core.hooksPath` propio encadenado no está protegido; avisos de `session-start` pensados para el SDK; la guía no recoge el pendiente de `core.fileMode` | V3-1 = A3-4 = P3-7, P3-6, A3-2 = P3-5, A3-3, A3-prev-A2-7, A3-5, A3-6, P3-8, P3-9 | menores y retoques |

## Disposición (gate **Resolución** 👤)

Decidida por una persona el 2026-10-17:

- **En esta PR** (ronda 4 de `apply`, slices T1-T7 de `tasks.md`): los defectos 1 y 2
  (bloqueantes), 3 (alinear la spec con la decisión) y 4 (`AGENTS.md` pasa a la política del
  propio SDK), más los textos baratos del 6: los README con la regla vigente, el `git add` de la
  skill y el pendiente de `core.fileMode` en la guía.
- **Cambio propio**: el defecto 5, la versión del SDK que instala `setup` (P3-4).
- **Deuda registrada**: el parser y los comentarios en línea (A3-3), la excepción de `.claude/`
  (A3-2 = P3-5), la prueba de humo con todas las tools (A3-prev-A2-7), el `core.hooksPath`
  propio encadenado (A3-5, se documenta como límite), las rutas relativas de `session-start`
  (A3-6) y los avisos pensados para el SDK (P3-8).
