# STATUS — ¿En qué punto está el framework?

> Foto del estado, en dos niveles: **roadmap** (qué fase del SDK construimos) y **ciclo**
> (en qué fase §7 está el cambio activo). Se actualiza al abrir y al archivar cada cambio.
> Desde la fase 4, `doctor --status` generará este fichero; hasta entonces, se mantiene a mano.

**Última actualización**: 2026-09-26 · `framework-semantics` completo y pendiente de revisión humana; `git-gates` aparcado

## Posición actual

| Nivel | Estado |
|---|---|
| **Roadmap** | Fases 0 y 1 ✅ archivadas · **fase 2 `git-gates` APARCADA en Propose** (rama `feature/git-gates`, sin trabajo a medias) · en curso: **`framework-semantics`** (fuera de roadmap: fija el vocabulario antes de seguir construyendo) |
| **Loop** | Stage **Engine** → **Tribunal** — el expediente `framework-semantics` está implementado (9/10 tareas) y espera revisión humana, merge y archive |
| **Niveles entregados** | **Guardia** al 50%: el puesto Centinela operativo; faltan Esclusa (fase 2) y Aduana (fase 3) |

## Roadmap

| Fase | Cambio | Nivel | Estado |
|---|---|---|---|
| 0 | `bootstrap-method` | — | ✅ Archivada (`2026-07-27`) — [change](openspec/changes/archive/2026-07-27-bootstrap-method/proposal.md) |
| 1 | `sentinel-guard` | 0 | ✅ Archivada (`2026-08-05`) — hook único + política + break-glass auditado; 15 casos en el fixture; endurecida tras panel adversarial |
| 2 | `git-gates` | 0 | ⏸️ **Aparcada en Propose** — se retoma tras la semántica |
| 3 | `ci-gate` + `spec-coverage` CLI | 0/1 | Pendiente |
| 4 | `sdd-cycle` | 1 | Pendiente |
| 5 | `release-hotfix` | 1 | Pendiente |
| 6 | `team` | 2 | Pendiente |
| 7 | `agent-run-audit` *(opcional)* | 2 | Pendiente |

## Contratos vigentes

- **Specs vivas**: [`sdk-method`](openspec/specs/sdk-method/spec.md) (método y symlinks
  multi-copilot) y [`sentinel-guard`](openspec/specs/sentinel-guard/spec.md) (el puesto
  Centinela). Todo cambio de framework nace con su expediente.
- **En revisión**: el delta `framework-semantics` (`SC-framework-semantics-01..08`) — al
  archivarse, el vocabulario de [docs/05-semantica.md](docs/05-semantica.md) pasa a contrato.
- **La política**: [sentinel/policy.yaml](sentinel/policy.yaml) — **con enforcement real**
  desde la fase 1 a través del Centinela.

## Salud / infraestructura

| Check | Estado |
|---|---|
| `fixture/verify.sh` | ✅ verde — 15 casos de guardarraíles + estructura + semántica (términos, slugs y caminos de vuelta) |
| `openspec validate --all --strict` | ✅ verde (2 specs vivas + el expediente `framework-semantics`) |
| CI (`.github/workflows/fixture.yml`) | ✅ activo (remote `mrompo/spec-sentinel-sdk`), matriz macOS + Linux |
| KPIs activos (docs/04) | `overrides break-glass` — `sentinel/overrides.log` (vacío: ninguna excepción usada) |
| Enforcement real | **Puesto Centinela activo en este repo** (`.claude/settings.json`): el agente no puede commitear en ramas protegidas, tocar ficheros gestionados, debilitar tests ni desarmar el propio guard. Esclusa y Aduana llegan en fases 2-3 |

## Deudas / pendientes conscientes

- El artefacto de revisión del plan menciona aún `docs/02`/`docs/03` (la investigación se movió
  al repo hermano `../spec-sentinel-research/`); se corrige en la próxima republicación.
- **Falso positivo del Centinela**: la regla `self-protection` bloquea también comandos de solo
  lectura que *nombran* ficheros protegidos (p. ej. un `git diff` de la política). Es el límite
  "evalúa texto" documentado; necesita un caso en el banco y su ajuste en un change propio.
- Renombrar el job de CI `verify` (colisión asumida en docs/05 §10).
- Convención aprendida en fase 0: proposals con cabeceras `## Why` / `## What Changes`.
