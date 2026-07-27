# STATUS — ¿En qué punto está el framework?

> Foto del estado, en dos niveles: **roadmap** (qué fase del SDK construimos) y **ciclo**
> (en qué fase §7 está el cambio activo). Se actualiza al abrir y al archivar cada cambio.
> Desde la fase 4, `doctor --status` generará este fichero; hasta entonces, se mantiene a mano.

**Última actualización**: 2026-07-27 · tras archivar `bootstrap-method`

## Posición actual

| Nivel | Estado |
|---|---|
| **Roadmap** | Fase 0 ✅ completada → **fase 1 `sentinel-guard`, sin abrir** |
| **Ciclo (§7)** | **Entre fases** — no hay cambio activo. Siguiente acción: abrir `openspec/changes/sentinel-guard/` (proposal + tasks + delta spec) → eso nos pone en **Propose**, con design gate humano antes de implementar |
| **Tiers entregados** | Ninguno aún — el Tier 0 se completa con las fases 1-3 |

## Roadmap

| Fase | Cambio | Tier | Estado |
|---|---|---|---|
| 0 | `bootstrap-method` | — | ✅ Archivada (`2026-07-27`) — [change](openspec/changes/archive/2026-07-27-bootstrap-method/proposal.md) |
| 1 | `sentinel-guard` | 0 | ⬅️ **Siguiente** (contrato ya negociado en [sentinel/policy.yaml](sentinel/policy.yaml)) |
| 2 | `git-gates` | 0 | Pendiente |
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
| `fixture/verify.sh` | ✅ verde (local) |
| `openspec validate --all --strict` | ✅ verde (CLI instalado vía brew) |
| CI (`.github/workflows/fixture.yml`) | ⚠️ **inactivo — el repo no tiene remote**; se activa con `gh repo create … --push` |
| KPIs activos (docs/04) | Ninguno — el primero (`overrides break-glass`) llega con la fase 1 |
| Enforcement real | Solo el fixture; los gates del ciclo son aún disciplina manual (por diseño: cada fase convierte uno en duro) |

## Deudas / pendientes conscientes

- Crear remote en GitHub para activar el CI (decisión de visibilidad: el plan es MIT/público).
- El artefacto de revisión del plan menciona aún `docs/02`/`docs/03` (la investigación se movió
  al repo hermano `../spec-sentinel-research/`); se corrige en la próxima republicación.
- Convención aprendida en fase 0: proposals con cabeceras `## Why` / `## What Changes`.
