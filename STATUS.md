# STATUS — ¿En qué punto está el framework?

> Foto del estado, en dos niveles: **roadmap** (qué fase del SDK construimos) y **ciclo**
> (en qué fase §7 está el cambio activo). Se actualiza al abrir y al archivar cada cambio.
> Desde la fase 4, `doctor --status` generará este fichero; hasta entonces, se mantiene a mano.

**Última actualización**: 2026-08-05 · fase 1 archivada; fase 2 abierta

## Posición actual

| Nivel | Estado |
|---|---|
| **Roadmap** | Fases 0 y 1 ✅ archivadas → **fase 2 `git-gates`** |
| **Ciclo (§7)** | **Propose** (fase 2) — capa 3 (git hooks) + instalador `setup` |
| **Tiers entregados** | Tier 0 al 50%: capa 2 (guardarraíles de agente) operativa; faltan capa 3 (fase 2) y capa 4 (fase 3) |

## Roadmap

| Fase | Cambio | Tier | Estado |
|---|---|---|---|
| 0 | `bootstrap-method` | — | ✅ Archivada (`2026-07-27`) — [change](openspec/changes/archive/2026-07-27-bootstrap-method/proposal.md) |
| 1 | `sentinel-guard` | 0 | ✅ Archivada (`2026-08-05`) — hook único + política + break-glass auditado; 15 casos en el fixture; endurecida tras panel adversarial |
| 2 | `git-gates` | 0 | 🔄 **En curso — Propose** |
| 3 | `ci-gate` + `spec-coverage` CLI | 0/1 | Pendiente |
| 4 | `sdd-cycle` | 1 | Pendiente |
| 5 | `release-hotfix` | 1 | Pendiente |
| 6 | `team` | 2 | Pendiente |
| 7 | `agent-run-audit` *(opcional)* | 2 | Pendiente |

## Contratos vigentes

- **Specs vivas**: [`openspec/specs/sdk-method/`](openspec/specs/sdk-method/spec.md) — 2 requirements,
  4 escenarios (`SC-sdk-method-01..04`). Todo cambio de framework nace con su change; symlinks
  multi-copilot verificados por el fixture.
- **Política de guardarraíles**: [sentinel/policy.yaml](sentinel/policy.yaml) — completa como
  contrato, **sin lógica todavía** (la implementa la fase 1).

## Salud / infraestructura

| Check | Estado |
|---|---|
| `fixture/verify.sh` | ✅ verde — 15 casos de guardarraíles + estructura |
| `openspec validate --all --strict` | ✅ verde (2 specs vivas: `sdk-method`, `sentinel-guard`) |
| CI (`.github/workflows/fixture.yml`) | ✅ activo (remote `mrompo/spec-sentinel-sdk`), matriz macOS + Linux |
| KPIs activos (docs/04) | `overrides break-glass` — `sentinel/overrides.log` (vacío: ninguna excepción usada) |
| Enforcement real | **Capa 2 activa en este repo** (`.claude/settings.json`): el agente no puede commitear en ramas protegidas, tocar ficheros gestionados, debilitar tests ni desarmar el propio guard. Capas 3-4 llegan en fases 2-3 |

## Deudas / pendientes conscientes

- Crear remote en GitHub para activar el CI (decisión de visibilidad: el plan es MIT/público).
- El artefacto de revisión del plan menciona aún `docs/02`/`docs/03` (la investigación se movió
  al repo hermano `../spec-sentinel-research/`); se corrige en la próxima republicación.
- Convención aprendida en fase 0: proposals con cabeceras `## Why` / `## What Changes`.
