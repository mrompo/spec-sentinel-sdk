# STATUS — ¿En qué punto está el framework?

> Foto del estado, en dos niveles: **roadmap** (qué fase del SDK construimos) y **ciclo**
> (en qué fase §7 está el cambio activo). Se actualiza al abrir y al archivar cada cambio.
> Desde la fase 4, `doctor --status` generará este fichero; hasta entonces, se mantiene a mano.

**Última actualización**: 2026-10-16 · `git-gates`: PR 1/3 (#3) y PR 2/3 (#4) en `main` · PR 3/3 (instalación): el panel dio `HOLD` dos veces; la tercera ronda de arreglos está hecha y se relanza el panel

## Posición actual

| Nivel | Estado |
|---|---|
| **Roadmap** | Fases 0 y 1 ✅ archivadas · `framework-semantics` ✅ en `main` (fuera de roadmap) · `pr-format` ✅ en `main` (fuera de roadmap) · **fase 2 `git-gates`** en `apply` (PR 3/3) |
| **Loop** | `git-gates`: PR 1/3 (la Esclusa) ✅ en `main` (#3) · PR 2/3 (ficheros protegidos) ✅ en `main` (#4) · **PR 3/3 (instalación): `review` dio `HOLD` dos veces ([review/](openspec/changes/git-gates/review/README.md), [round2/](openspec/changes/git-gates/review/round2/README.md)), ronda 3 de `apply` hecha, se relanza `review`** |
| **Niveles entregados** | **Guardia**, salvo la Aduana: Centinela y Esclusa activos en este repo e instalables en cualquiera con `setup`; la Aduana llega en la fase 3 |

## Roadmap

| Fase | Cambio | Nivel | Estado |
|---|---|---|---|
| 0 | `bootstrap-method` | — | ✅ Archivada (`2026-07-27`) — [change](openspec/changes/archive/2026-07-27-bootstrap-method/proposal.md) |
| 1 | `sentinel-guard` | 0 | ✅ Archivada (`2026-08-05`) — hook único + política + break-glass auditado; 15 casos en el fixture; endurecida tras panel adversarial |
| — | `framework-semantics` | — | ✅ Archivada (`2026-09-28`, en `main` por la PR #1) — vocabulario del framework en `docs/05-semantica.md`; 8 escenarios, verificados por el banco |
| — | `pr-format` | — | ✅ Archivada (`2026-09-29`, en `main` por la PR #2) — título en Conventional Commits + diez secciones fijas; la plantilla la verifica el banco. Adelanta la plantilla de la fase 5 |
| 2 | `git-gates` | 0 | 🔄 **Apply** — gates Intención, Claridad y Plan aprobados (2026-09-29); PRs 1/3 y 2/3 en `main`; la 3/3 (instalación) pasó dos veces por el panel (`HOLD`), tiene hecha la tercera ronda de arreglos y vuelve al panel |
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
| `fixture/verify.sh` | ✅ verde — 20 casos del Centinela + 16 de la Esclusa + 13 de instalación (uno end-to-end sobre `demo-app`) + estructura + semántica + plantilla de PR |
| `openspec validate --all --strict` | ✅ verde (3 specs vivas + los expedientes activos) |
| CI (`.github/workflows/fixture.yml`) | ✅ activo (remote `mrompo/spec-sentinel-sdk`), matriz macOS + Linux |
| KPIs activos (docs/04) | `overrides break-glass` — `sentinel/overrides.log`: 4 excepciones, todas del 2026-10-17, las llaves que una persona concedió para que el agente escribiera los ficheros protegidos de la ronda 3 de `git-gates` (S2, S4) |
| Enforcement real | **Centinela y Esclusa activos en este repo**. El Centinela (`.claude/settings.json`) impide al agente commitear en ramas protegidas, tocar ficheros gestionados, debilitar tests o desarmar el propio guard. La Esclusa (`core.hooksPath` → `sentinel/githooks`, desde el 2026-10-16) revisa cada commit y cada push. La Aduana llega en la fase 3 |

## Deudas / pendientes conscientes

- El artefacto de revisión del plan menciona aún `docs/02`/`docs/03` (la investigación se movió
  al repo hermano `../spec-sentinel-research/`); se corrige en la próxima republicación.
- **Falso positivo del Centinela**: la regla `self-protection` bloquea también comandos de solo
  lectura que *nombran* ficheros protegidos (p. ej. un `git diff` de la política). Es el límite
  "evalúa texto" documentado; necesita un caso en el banco y su ajuste en un change propio.
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
- **El SDK no declara su `stack.yaml`**: en este repo la Esclusa omite format, lint y tests
  con aviso. Con `tests: bash fixture/verify.sh`, el `pre-push` correría el banco antes de
  cada push.
- Convención aprendida en fase 0: proposals con cabeceras `## Why` / `## What Changes`.
