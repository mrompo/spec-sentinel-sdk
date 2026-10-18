# STATUS — ¿En qué punto está el framework?

> Foto del estado, en dos niveles: **roadmap** (qué fase del SDK construimos) y **ciclo**
> (en qué fase §7 está el cambio activo). Se actualiza al abrir y al archivar cada cambio.
> Desde la fase 4, `doctor --status` generará este fichero; hasta entonces, se mantiene a mano.

**Última actualización**: 2026-10-18 · `git-gates`: PR 1/3 (#3) y PR 2/3 (#4) en `main` · PR 3/3 (instalación): el panel dio `HOLD` cinco veces; la sexta ronda de arreglos (jq aislado, finales de línea, lo personal comprobado con git) está hecha y se relanza el panel; lo del Centinela pasa a `sentinel-paths` · historia reescrita con los mensajes de commit en español (misma topología y contenido)

## Posición actual

| Nivel | Estado |
|---|---|
| **Roadmap** | Fases 0 y 1 ✅ archivadas · `framework-semantics` ✅ en `main` (fuera de roadmap) · `pr-format` ✅ en `main` (fuera de roadmap) · **fase 2 `git-gates`** en `apply` (PR 3/3) |
| **Loop** | `git-gates`: PR 1/3 (la Esclusa) ✅ en `main` (#3) · PR 2/3 (ficheros protegidos) ✅ en `main` (#4) · **PR 3/3 (instalación): `review` dio `HOLD` cinco veces ([review/](openspec/changes/git-gates/review/README.md), [round2/](openspec/changes/git-gates/review/round2/README.md), [round3/](openspec/changes/git-gates/review/round3/README.md), [round4/](openspec/changes/git-gates/review/round4/README.md), [round5/](openspec/changes/git-gates/review/round5/README.md)), ronda 6 de `apply` hecha, se relanza `review`** |
| **Niveles entregados** | **Guardia**, salvo la Aduana: Centinela y Esclusa activos en este repo e instalables en cualquiera con `setup`; la Aduana llega en la fase 3 |

## Roadmap

| Fase | Cambio | Nivel | Estado |
|---|---|---|---|
| 0 | `bootstrap-method` | — | ✅ Archivada (`2026-07-27`) — [change](openspec/changes/archive/2026-07-27-bootstrap-method/proposal.md) |
| 1 | `sentinel-guard` | 0 | ✅ Archivada (`2026-08-05`) — hook único + política + break-glass auditado; 15 casos en el fixture; endurecida tras panel adversarial |
| — | `framework-semantics` | — | ✅ Archivada (`2026-09-28`, en `main` por la PR #1) — vocabulario del framework en `docs/05-semantica.md`; 8 escenarios, verificados por el banco |
| — | `pr-format` | — | ✅ Archivada (`2026-09-29`, en `main` por la PR #2) — título en Conventional Commits + diez secciones fijas; la plantilla la verifica el banco. Adelanta la plantilla de la fase 5 |
| 2 | `git-gates` | 0 | 🔄 **Apply** — gates Intención, Claridad y Plan aprobados (2026-09-29); PRs 1/3 y 2/3 en `main`; la 3/3 (instalación) pasó cinco veces por el panel (`HOLD`), tiene hecha la sexta ronda de arreglos y vuelve al panel |
| 3 | `ci-gate` + `spec-coverage` CLI | 0/1 | Pendiente |
| 4 | `sdd-cycle` | 1 | Pendiente |
| 5 | `release-hotfix` | 1 | Pendiente |
| 6 | `team` | 2 | Pendiente |
| 7 | `agent-run-audit` *(opcional)* | 2 | Pendiente |

## Contratos vigentes

- **Specs vivas**: [`sdk-method`](openspec/specs/sdk-method/spec.md) (método y symlinks
  multi-copilot) y [`sentinel-guard`](openspec/specs/sentinel-guard/spec.md) (el puesto
  Centinela). Todo cambio de framework nace con su expediente.
- **Semántica**: [`framework-semantics`](openspec/specs/framework-semantics/spec.md) — el
  vocabulario de [docs/05-semantica.md](docs/05-semantica.md) es contrato
  (`SC-framework-semantics-01..08`).
- **La política**: [sentinel/policy.default.yaml](sentinel/policy.default.yaml) (la del SDK)
  + [sentinel/policy.yaml](sentinel/policy.yaml) (la de este repo, nivel Método) — **con
  enforcement real** desde la fase 1 a través del Centinela.

## Salud / infraestructura

| Check | Estado |
|---|---|
| `fixture/verify.sh` | ✅ verde — 20 casos del Centinela + 16 de la Esclusa + 17 de instalación (uno end-to-end sobre `demo-app`) + estructura + semántica + plantilla de PR. El banco de instalación necesita jq |
| `openspec validate --all --strict` | ✅ verde (3 specs vivas + los expedientes activos) |
| CI (`.github/workflows/fixture.yml`) | ✅ activo (remote `mrompo/spec-sentinel-sdk`), matriz macOS + Linux |
| KPIs activos (docs/04) | `overrides break-glass` — `sentinel/overrides.log`: 12 excepciones, del 2026-10-17 y el 2026-10-18. Once son llaves que una persona concedió para que el agente escribiera los ficheros protegidos de las rondas 3 a 6 de `git-gates`; una la gastó un agente revisor con un comando de solo lectura (va a `sentinel-paths`) |
| Enforcement real | **Centinela y Esclusa activos en este repo**. El Centinela (`.claude/settings.json`) impide al agente commitear en ramas protegidas, tocar ficheros gestionados, debilitar tests o desarmar el propio guard. La Esclusa (`core.hooksPath` → `sentinel/githooks`, desde el 2026-10-16) revisa cada commit y cada push. La Aduana llega en la fase 3 |

## Deudas / pendientes conscientes

- El artefacto de revisión del plan menciona aún `docs/02`/`docs/03` (la investigación se movió
  al repo hermano `../spec-sentinel-research/`); se corrige en la próxima republicación.
- **Falso positivo del Centinela**: la regla `self-protection` bloquea también comandos de solo
  lectura que *nombran* ficheros protegidos (p. ej. un `git diff` de la política). Es el límite
  "evalúa texto" documentado; va en el expediente
  [`sentinel-paths`](openspec/changes/sentinel-paths/proposal.md).
- **El Centinela decide por el texto de la ruta y fichero a fichero** (quinta revisión de
  `git-gates`): las carpetas protegidas se mueven o se borran enteras, un enlace abre los
  ficheros protegidos, la configuración de git de un repo bare no está protegida, hay vías hacia
  `core.hooksPath` que no lo nombran, los patrones de la configuración de git dan falsos
  positivos, `CLAUDE_CONFIG_DIR` en otra ruta queda sin proteger y la llave la gasta la primera
  acción bloqueada de cualquier agente. Expediente propio,
  [`sentinel-paths`](openspec/changes/sentinel-paths/proposal.md), con el gate Intención
  pendiente.
- **La protección de ficheros choca con operaciones legítimas.** Además del falso positivo de
  arriba, `managed-files` y `self-protection` impiden al agente: leer (`grep`) dentro del
  archivo de expedientes, rellenar el `Purpose` de una spec viva recién archivada, deshacer un
  `openspec archive` que aún no está commiteado (pasó en `pr-format`, lo deshizo una persona) e
  incluso escribir un texto que *menciona* esas rutas en un comando. Va en un expediente propio
  del Centinela, junto al falso positivo.
- Las specs vivas `sentinel-guard` y `framework-semantics` tienen el `Purpose` en «TBD» (lo
  deja `openspec archive`); están protegidas como ficheros gestionados, así que lo rellena una
  persona.
- Renombrar el job de CI `verify` (colisión asumida en docs/05 §10).
- **Convivencia de la Esclusa con otros gestores de git hooks** (husky, lefthook, pre-commit,
  git-lfs): sacada de `git-gates` tras su segunda revisión; expediente propio,
  [`hook-coexistence`](openspec/changes/hook-coexistence/proposal.md), con el gate Intención
  pendiente.
- **Versión del SDK instalada** (P3-4 de la tercera revisión de `git-gates`): `setup` no la
  registra, y reinstalar desde una copia más vieja revierte el enforcement sin aviso. Expediente
  propio, [`sdk-version`](openspec/changes/sdk-version/proposal.md), con el gate Intención
  pendiente.
- **Deuda de la tercera revisión de `git-gates`** (decisión del 2026-10-17, detalle en
  [round3/](openspec/changes/git-gates/review/round3/README.md)):
  - el parser de la política no recorta los comentarios en línea y mezcla una regla que no
    empieza por `- id:` con la anterior (A3-3);
  - la excepción que propone `setup` para `.claude/` es demasiado amplia y puede volver a
    ignorar `commands/`, `agents/` y `skills/` (A3-2 = P3-5);
  - la prueba de humo de `setup` no cubre Write, Grep, Glob, MultiEdit ni NotebookEdit
    (A3-prev-A2-7);
  - `session-start` compara texto en rutas relativas de `core.hooksPath` (A3-6) y sus avisos
    dan por hecho que el repo es el SDK (`STATUS.md`, OpenSpec) (P3-8).
- **Deuda de la cuarta revisión de `git-gates`** (decisión del 2026-10-18, detalle en
  [round4/](openspec/changes/git-gates/review/round4/README.md)):
  - el instalador se protege por sus dos rutas (`ai-specs/skills/setup/` y el enlace
    `~/.claude/skills/spec-sentinel-setup/`): un enlace con otro nombre no está protegido
    (resto de P4-5);
  - `setup` no valida el esquema completo de Claude Code, solo `disableAllHooks` y `env`; el
    resto queda como límite documentado y se comprueba con `/hooks` (resto de V4-3);
  - la carpeta de la skill en el SDK se llama `setup` y la skill `spec-sentinel-setup`: la
    Agent Skills spec pide que coincidan, y renombrar la carpeta toca el instalador y sus
    reglas.
- **El SDK no declara su `stack.yaml`**: en este repo la Esclusa omite format, lint y tests
  con aviso. Con `tests: bash fixture/verify.sh`, el `pre-push` correría el banco antes de
  cada push.
- Convención aprendida en fase 0: proposals con cabeceras `## Why` / `## What Changes`.
