# Tasks — git-gates

**Objetivo**: el nivel Guardia instalable en cualquier repo con un comando, con la Esclusa real.
**Ritmo**: un slice = caso del banco en rojo → implementación mínima → verde → commit atómico.
**Posición en el Loop**: PR 1/3 (la Esclusa) en Delivery · `merge` — slices 1-5 hechos (2026-09-30).

## Engine · antes de teclear

- [x] 0. `propose`: expediente reescrito con el vocabulario de `docs/05-semantica.md`
- [x] 0a. Gate **Intención** 👤 — aprobado el 2026-09-29 (proposal §Decisiones 1-2)
- [x] 0b. `tune` → gate **Claridad**: resolver las cuestiones 1-5 de la proposal y cerrar los
       huecos del delta spec detectados al reabrir:
       - falta el escenario de **fallo duro** del skip-vs-fail (entorno roto), el requirement ya
         lo exige;
       - falta un escenario de **formato/lint** en `pre-commit` (hoy solo cubre secretos);
       - separar la capability `sdk-setup` si se aprueba la cuestión 2
- [x] 0c. `breakdown` → gate **Plan**: aprobado el 2026-09-29 — tres PRs (abajo)

## Checklist (`apply` ↺ `verify`, por slice)

**Tres PRs** (gate Plan): **1/3 · La Esclusa** = slices 1, 2, 3, 4, 5a, 5
· **2/3 · Ficheros protegidos** 👤 = slices 3b, 6 y 6b · **3/3 · Instalación** = slices 7, 8, 9, 10.

- [x] 1. Runner de git hooks en el banco: workspace con `git init` + commits reales
       (aprovecha `fixture/hooks/harness.sh`); se engancha a `verify.sh`
- [x] 2. `commit-msg` en bash puro: Conventional Commits + bypass merges/release
       (SC-git-gates-01, 02)
- [x] 3. `sentinel/adapters/stack.yaml` + autodetección Node/Laravel (SC-git-gates-07)
- [ ] 3b. 👤 Renombrado del fichero de stack en `post-edit.sh` — **fichero protegido**: lo hace
       una persona o con la llave, y queda en la bitácora
- [x] 4. `pre-commit`: gitleaks + format --check + lint sobre staged, con **skip-vs-fail**
       (SC-git-gates-03, 06, 08, 09)
- [x] 5a. `docs/05-semantica.md`: el gate Esclusa se cierra en dos tiempos (decisión 1)
- [x] 5. `pre-push`: tests + rama protegida (cierra el TOCTOU) + openspec validate opcional
       (SC-git-gates-04, 05)
- [ ] 6. 👤 Separación de la política en distribuida (`policy.default.yaml`) y del consumidor
       (SC-sdk-setup-05) — **fichero protegido**: igual que 3b
- [ ] 6b. 👤 Proteger la Esclusa en la política — **fichero protegido**:
       - `self-protection` debe cubrir `sentinel/githooks/` y `sentinel/adapters/stack.sh` (los
         hooks lo cargan con `source`): hoy el agente podría desactivar la Esclusa editándolos;
       - `no-hook-disabling` debe cubrir `SENTINEL_GITLEAKS_BIN=` y `SENTINEL_OPENSPEC_BIN=`,
         las variables de prueba de los hooks, para que el agente no salte gitleaks u openspec
- [ ] 7. Skill `setup`: instalación de un comando (copia, `core.hooksPath`, fusión de
       `.claude/settings.json` con `jq` o fragmento, backup, detección de stack)
       (SC-sdk-setup-02, 03, 04)
- [ ] 8. Caso de instalación end-to-end en `demo-app/`: tras `setup`, los gates bloquean
       (SC-sdk-setup-01) — DoD de la fase
- [ ] 9. 👤 Auto-instalación en este repo (`core.hooksPath` apuntando a `sentinel/githooks`),
       solo con el banco en verde — la regla `no-hook-disabling` impide al agente tocar
       `core.hooksPath`, así que lo ejecuta una persona
- [ ] 10. `STATUS.md` + sección
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
