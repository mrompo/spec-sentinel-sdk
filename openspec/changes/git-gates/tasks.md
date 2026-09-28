# Tasks — git-gates

**Objetivo**: el nivel Guardia instalable en cualquier repo con un comando, con la Esclusa real.
**Ritmo**: un slice = caso del banco en rojo → implementación mínima → verde → commit atómico.
**Posición en el Loop**: Engine · `propose` reabierto (2026-09-28) → espera el gate **Intención**.

## Engine · antes de teclear

- [x] 0. `propose`: expediente reescrito con el vocabulario de `docs/05-semantica.md`
- [ ] 0a. Gate **Intención** 👤 — ¿merece la pena y está justificado? (proposal §Why)
- [ ] 0b. `tune` → gate **Claridad**: resolver las cuestiones 1-5 de la proposal y cerrar los
       huecos del delta spec detectados al reabrir:
       - falta el escenario de **fallo duro** del skip-vs-fail (entorno roto), el requirement ya
         lo exige;
       - falta un escenario de **formato/lint** en `pre-commit` (hoy solo cubre secretos);
       - separar la capability `sdk-setup` si se aprueba la cuestión 2
- [ ] 0c. `breakdown` → gate **Plan**: confirmar los slices de abajo, cada uno mergeable solo

## Checklist (`apply` ↺ `verify`, por slice)

- [ ] 1. Runner de git hooks en el banco: workspace con `git init` + commits reales
       (aprovecha `fixture/hooks/harness.sh`); se engancha a `verify.sh`
- [ ] 2. `commit-msg` en bash puro: Conventional Commits + bypass merges/release
       (SC-git-gates-01, 02)
- [ ] 3. `sentinel/adapters/stack.yaml` + autodetección Node/Laravel (SC-git-gates-07)
- [ ] 3b. 👤 Renombrado del fichero de stack en `post-edit.sh` — **fichero protegido**: lo hace
       una persona o con la llave, y queda en la bitácora
- [ ] 4. `pre-commit`: gitleaks + format --check + lint sobre staged, con **skip-vs-fail**
       (SC-03, 06)
- [ ] 5. `pre-push`: tests + rama protegida (cierra el TOCTOU) + openspec validate opcional
       (SC-04, 05)
- [ ] 6. 👤 Separación de la política en distribuida (`policy.default.yaml`) y del consumidor
       (SC-09) — **fichero protegido**: igual que 3b
- [ ] 7. Skill `setup`: instalación de un comando (copia, `core.hooksPath`, fusión de
       `.claude/settings.json` con backup, detección de stack) (SC-08)
- [ ] 8. Caso de instalación end-to-end en `demo-app/`: tras `setup`, los gates bloquean
       (SC-10) — DoD de la fase
- [ ] 9. Auto-instalación en este repo (`core.hooksPath` apuntando a `sentinel/githooks`),
       solo con el banco en verde
- [ ] 10. `docs/05-semantica.md` (gate Esclusa, según la cuestión 1) + `STATUS.md` + sección
       «Instalar en tu proyecto» de `docs/guia-uso.md`

## Tribunal y Delivery

- [ ] 11. `review` adversarial (tres lentes) → **Veredicto**
- [ ] 12. `merge` a `main` (una persona) → `archive`

## Notas de diseño (design gate)

- La Esclusa **no depende** del adaptador para funcionar: si no hay `stack.yaml`, hace skip con
  aviso (un repo recién clonado no debe romperse).
- `pre-push` es el sitio correcto para la rama protegida: ahí el commit ya existe y no hay
  TOCTOU posible (hallazgo del panel adversarial en fase 1).
- El instalador **nunca pisa** configuración del consumidor: backup + fusión conservadora, y
  ante la duda, instrucción manual explícita.
- Los slices 👤 se agrupan aparte para que la excepción de autoprotección cubra lo mínimo.
