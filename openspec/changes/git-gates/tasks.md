# Tasks — git-gates

**Objetivo**: el nivel Guardia instalable en cualquier repo con un comando, con la Esclusa real.
**Ritmo**: un slice = caso del banco en rojo → implementación mínima → verde → commit atómico.
**Posición en el Loop**: PR 1/3 ✅ en `main` (#3) · PR 2/3 ✅ en `main` (#4) · PR 3/3: `apply` terminado (2026-10-16), toca `review`.

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
· **2/3 · Ficheros protegidos** 👤 = slices 3b y 6b · **3/3 · Instalación** = slices 6, 7, 8, 9, 10
(el 6 pasó a la 3/3 el 2026-09-30: cómo lee el Centinela dos políticas solo tiene sentido con el instalador).

- [x] 1. Runner de git hooks en el banco: workspace con `git init` + commits reales
       (aprovecha `fixture/hooks/harness.sh`); se engancha a `verify.sh`
- [x] 2. `commit-msg` en bash puro: Conventional Commits + bypass merges/release
       (SC-git-gates-01, 02)
- [x] 3. `sentinel/adapters/stack.yaml` + autodetección Node/Laravel (SC-git-gates-07)
- [x] 3b. 👤 Renombrado del fichero de stack en `post-edit.sh` — **fichero protegido**: lo hace
       una persona o con la llave, y queda en la bitácora
- [x] 4. `pre-commit`: gitleaks + format --check + lint sobre staged, con **skip-vs-fail**
       (SC-git-gates-03, 06, 08, 09)
- [x] 4b. gitleaks **obligatorio** (decisión 6, 2026-09-30): sin él, fallo duro con la
       instrucción de instalación (SC-git-gates-10) + documentado en la guía y en el README
- [x] 5b. Excepción auditada de la Esclusa (decisión 8, 2026-09-30): la misma llave que el
       Centinela, registrada en la bitácora (SC-git-gates-11, 12, 13)
- [x] 5a. `docs/05-semantica.md`: el gate Esclusa se cierra en dos tiempos (decisión 1)
- [x] 5. `pre-push`: tests + rama protegida (cierra el TOCTOU) + openspec validate opcional
       (SC-git-gates-04, 05)
- [x] 6. 👤 Separación de la política en distribuida (`policy.default.yaml`) y del consumidor
       (SC-sdk-setup-05, SC-sentinel-guard-17..19, SC-git-gates-16) — **fichero protegido**:
       lo aplicó una persona el 2026-10-16 desde un parche revisado, con el banco en verde
       (`9196c16`). **Opción A** (decidida el 2026-10-12): primero la distribuida, el
       consumidor solo añade reglas; un id del SDK repetido es error de política; `sdd:` del
       consumidor, o de la distribuida (que trae `false`). Límite asumido: el consumidor no
       puede cambiar la lista de ramas protegidas (`protected-branches` es del SDK); si hace
       falta, en un cambio aparte
- [x] 6b. 👤 Proteger la Esclusa en la política — **fichero protegido**:
       - `self-protection` debe cubrir `sentinel/githooks/` y `sentinel/adapters/stack.sh` (los
         hooks lo cargan con `source`): hoy el agente podría desactivar la Esclusa editándolos;
       - `no-hook-disabling` debe cubrir `SENTINEL_GITLEAKS_BIN=` y `SENTINEL_OPENSPEC_BIN=`,
         las variables de prueba de los hooks, para que el agente no salte gitleaks u openspec
       - **PRIORIDAD**: `self-protection` debe cubrir `sentinel/.override`. Hoy el agente PUEDE
         crear la llave y concederse excepciones a sí mismo (sonda del 2026-09-30: Write,
         `echo >` y `tee` pasan con exit 0). Con su caso en `fixture/hooks/cases/`, que hoy
         ningún caso comprueba; la llave de la Esclusa depende de esto (SC-git-gates-11)
- [x] 7. Skill `setup`: instalación de un comando (copia, `core.hooksPath`, fusión de
       `.claude/settings.json` con `jq` o fragmento, backup, detección de stack) — y
       comprobar que gitleaks está instalado, para avisar al instalar y no en el primer commit
       (SC-sdk-setup-01..04, 06..08; el 05 a medias hasta el slice 6) — `ai-specs/skills/setup/`
       (`SKILL.md` + `setup.sh`), 8 casos en `fixture/install/`. Decisiones tomadas en `apply`:
       - exit 3 = «instalado con pasos pendientes» (sin jq, gitleaks ausente, git hooks
         previos): nunca éxito silencioso;
       - solo instala en la **raíz** de un repo (dentro de un subdirectorio caería en el repo
         padre); backups en `sentinel/.backup/<fecha>/`, fuera de git como la llave;
       - el stack detectado se escribe en `stack.proposed.yaml`; lo activa una persona;
       - un `core.hooksPath` previo, **también el global** de la persona, no se pisa: se
         explica cómo encadenar la Esclusa (afecta al slice 9 si la máquina tiene uno global)
- [x] 8. Caso de instalación end-to-end en `demo-app/`: tras `setup`, los gates bloquean
       (SC-sdk-setup-01) — DoD de la fase. `fixture/install/cases/sc-09-e2e-demo-app.sh`:
       instala, commitea la propia instalación (la Esclusa no se bloquea con sus ficheros) y,
       con los ficheros instalados, rechaza un secreto, un mensaje no conforme y un push a
       `main`; el Centinela protege las dos políticas y aplica una regla añadida por el
       proyecto. Falsificado con 8 mutantes (un puesto saboteado cada vez): todos rompen el caso
- [x] 9. 👤 Auto-instalación en este repo (`core.hooksPath` apuntando a `sentinel/githooks`),
       solo con el banco en verde — la regla `no-hook-disabling` impide al agente tocar
       `core.hooksPath`, así que lo ejecuta una persona. Hecho el 2026-10-16 (`9799824`, el
       primer commit que pasó por la Esclusa). En la máquina había un `core.hooksPath` global
       (`.githooks`) sin esa carpeta en el repo: `setup` proponía encadenar hooks que no
       existían. Corregido con su caso (`4e42c54` en rojo, `54dcf31`, SC-sdk-setup-08)
- [x] 10. `STATUS.md` + sección «Instalar en tu proyecto» de `docs/guia-uso.md`
- [x] 10b. 👤 Tres ficheros protegidos siguen hablando de una sola política (slice 6): el mapa
       de `AGENTS.md`, `sentinel/hooks/README.md` y el aviso de `session-start.sh`
       («Reglas: sentinel/policy.yaml»). Aplicado por una persona desde un parche revisado
       (`3646f5e`)

## Tribunal y Delivery

- [ ] 11. `review` adversarial (tres lentes) → **Veredicto**: **`HOLD`** el 2026-10-16
       ([`review/`](review/README.md)): 1 bloqueante y 12 graves validados → vuelta a `apply`
       tras la **Resolución** 👤. Foco anotado durante `apply`:
       - el agente puede ejecutar `setup.sh` en un repo consumidor, y eso sobrescribe ficheros
         protegidos con los del SDK (con backup): el Centinela solo ve el texto del comando;
       - la Verificación de la skill `setup` pide `exit 0` en la segunda ejecución, pero si la
         persona decidió encadenar sus hooks, `setup` saldrá con `3` siempre
### Ronda 2 de `apply`, tras el `HOLD` (disposición del 2026-10-16: todo lo validado)

- [x] R1. La instalación se cierra (A1 🛑, P3, A7): `setup` comprueba en vez de repetir — el
       cableado ya presente sin jq, el `hooksPath` escrito de otra forma, el encadenado hecho
       (`57bf6a7` en rojo, `43632bf`)
- [x] R2. Encadenar bien con hooks ajenos (A3, P1, P2, P4): un snippet único (guarda las refs
       de stdin, va al principio, `[ -x … ]` para los demás repos), husky v9 en
       `.husky/<hook>`, los de `.git/hooks` se encadenan donde están — `chain.sh`, la fuente
       que imprime `setup` y aplica el banco (sc-08, sc-10, con husky v9 y un pre-push tipo LFS)
- [x] R3. 👤 Las dos políticas (A2): cada una decide por su primera regla y gana la decisión
       más estricta — Centinela (**fichero protegido**; `06b2bbc` en rojo, aplicado en R8)
- [x] R4. El instalador no descablea (A4, V1, V3): `setup` valida el resultado de la fusión e
       ignora un jq dentro del repo (`dc427b5` en rojo, `600d3c9`, sc-11); 👤 en la política,
       `SENTINEL_[A-Z_]+=` en `no-hook-disabling` y `confirm` para ejecutar `setup.sh`
       (`06b2bbc` en rojo, aplicado en R8)
- [x] R5. Lo que llega al equipo (A5 = P6, P5): `setup` avisa si el `.gitignore` deja fuera lo
       que hay que versionar (`0138513` en rojo, `d57b1c5`, sc-12); la guía explica el paso por
       clon; 👤 `session-start` avisa si la Esclusa no está activa en el clon (`06b2bbc` en
       rojo, aplicado en R8)
- [x] R6. Actualizar el cableado (P8, A8): las entradas del SDK se reconocen por la ruta del
       script y se sustituyen; SAFE endurecido; si la fusión falla, fragmento y no `die`; el
       fragmento sale del `.claude/settings.json` del SDK (`dc427b5` en rojo, `600d3c9`)
- [x] R7. Menores (A6, A9, P9, P10, A10) + la nota de P7 en la guía (`0138513` en rojo,
       `d57b1c5` y la documentación)
- [x] R8. 👤 Parche de ficheros protegidos (R3, R4 y R5) aplicado por una persona, banco en verde
       (`75ea1bd`, el 2026-10-16: Centinela, política del SDK, `session-start` y sus textos)
- [x] R9. Relanzar el panel → **Veredicto**: **`HOLD`** otra vez el 2026-10-16
       ([`review/round2/`](review/round2/README.md)): 19 de los 21 validados de la primera
       ronda resueltos; un bloqueante nuevo (`lib/` ignorado) y 8 graves, la mitad por
       convivir con otros gestores de hooks. Pendiente la **Resolución** 👤

### Ronda 3 de `apply`, tras el segundo `HOLD` (disposición del 2026-10-16: temas 1-3 y 5)

- [x] S1. Lo que hay que versionar (A2-2 = P2-1 🛑, P2-7, P2-10): `setup` comprueba con
       `git check-ignore` todo lo que distribuye y lo del consumidor; avisa con
       `core.fileMode=false`; la excepción correcta cuando `.claude/` viene de fuera del repo
       (`1d1554e` en rojo, `b4864d7`)
- [x] S2. 👤 Las reglas del Centinela (A2-1 = V2-1): de todas las reglas que coinciden, en las
       dos políticas, gana la más estricta (ninguna `confirm` o `warn` tapa un `block`) —
       **fichero protegido**, escrito por el agente con una llave concedida por una persona
       (`72cfe7a`). A2-6 = V2-prevV1 y V2-6 quedan documentados como límite «regex evadibles»
       (decisión del 2026-10-16)
- [x] S3. El instalador (A2-prevA4 = V2-prevA4, A2-3 = P2-9, A2-5 = P2-6, A2-7): validar la
       estructura del cableado y no el texto; contar solo comandos; `SDK_ROOT` a través del
       symlink de la skill; la prueba de humo cubre también tools de fichero (`23448b1` en
       rojo, `83fae87`)
- [x] S4. 👤 Proteger lo que el agente no debe tocar (V2-5, V2-4, V2-2): el fragmento y los
       hooks donde queda encadenada la Esclusa (`self-protection`); el instalador, bloqueado con
       las herramientas de edición (`protect-installer`) y con aprobación humana para cualquier
       comando de shell que lo nombre (`install-needs-human`) — **fichero protegido** (`72cfe7a`)
- [x] S5. Retoque (A2-8, también en `session-start`) y documentación: el tema 4 como límite
       conocido en la guía y en `sentinel/README.md`, con su cambio OpenSpec propio,
       [`hook-coexistence`](../hook-coexistence/proposal.md) (Intención pendiente 👤)
- [x] S6. 👤 Ficheros protegidos de S2 y S4: en vez de parche, el agente los escribió con cuatro
       llaves de un solo uso que creó una persona (2026-10-17), registradas en
       `sentinel/overrides.log`; banco en verde (20 + 16 + 13 casos)
- [ ] S7. Relanzar el panel → **Veredicto**

- [ ] 12. `merge` a `main` (una persona) → `archive`

## Notas de diseño (design gate)

- La Esclusa **no depende** del adaptador para funcionar: si no hay `stack.yaml`, hace skip con
  aviso (un repo recién clonado no debe romperse).
- `pre-push` es el sitio correcto para la rama protegida: ahí el commit ya existe y no hay
  TOCTOU posible (hallazgo del panel adversarial en fase 1).
- El instalador **nunca pisa** configuración del consumidor: backup + fusión conservadora, y
  ante la duda, instrucción manual explícita.
- Los slices 👤 se agrupan aparte para que la excepción de autoprotección cubra lo mínimo.
