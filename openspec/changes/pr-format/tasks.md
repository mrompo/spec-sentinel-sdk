# Tasks — pr-format

**Objetivo**: toda PR se puede aprobar con criterio sin reconstruir el contexto a mano.
**Posición en el Loop**: Engine · `propose` (2026-09-28) → espera el gate **Intención**.

## Engine · antes de teclear

- [x] 0. `propose`: expediente abierto, con el formato completo en la proposal
- [ ] 0a. Gate **Intención** 👤 — cuestiones 1-3 de la proposal
- [ ] 0b. `tune` → gate **Claridad**: `openspec validate --strict`, sin preguntas abiertas

## Checklist

- [ ] 1. Check en el banco: la plantilla tiene las diez secciones (SC-pr-format-02), primero
       en rojo
- [ ] 2. `.github/pull_request_template.md` con las diez secciones y su línea de ayuda → verde
- [ ] 3. `docs/guia-uso.md`, paso 4: el formato y el enlace a la plantilla
- [ ] 4. `docs/01-plan-maestro.md`: la plantilla sale de la fase 5 (queda la procedencia
       automática) · `STATUS.md`
- [ ] 5. Dogfooding: la descripción de la PR #1 y la PR de este cambio, con el formato
- [ ] 6. Revisión humana → merge → archive

## Notas de diseño

- Los escenarios SC-01 y SC-03..08 describen **defectos de una PR concreta**. Hoy los detecta el
  revisor; en la fase 3 (`ci-gate`) la Aduana los comprueba en CI. SC-02 es el único que el
  banco puede falsificar ya, porque trata de la plantilla, no de una PR.
- El `N/A — motivo` es deliberado: una sección borrada no se distingue de una olvidada; una
  sección con su motivo, sí.
