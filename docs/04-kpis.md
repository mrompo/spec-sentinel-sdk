# 04 · KPIs del framework — definición instrumentable

> Cómo se captura cada KPI del plan §9. Principio: **el flujo genera los datos como
> subproducto de sus artefactos** — ningún KPI exige registro manual. Disponibilidad por
> fase del roadmap. Los KPIs se leen por tendencia, nunca como objetivo individual
> (ley de Goodhart: en cuanto un KPI se vuelve objetivo, deja de medir).

| KPI | Fórmula | Fuente de datos | Disponible desde |
|---|---|---|---|
| **Lead time** | `merged_at(última PR del cambio) − created_at(proposal.md)` | timestamps git de los artefactos del change + API del forge | Fase 4 (ciclo SDD) |
| **Change failure rate** | `nº cambios hotfix ÷ nº releases` por ventana | changes `hotfix-*` archivados + tags de release | Fase 5 |
| **MTTR** | `publicación del patch − timestamp de la referencia de incidente` (obligatoria en el carril) | metadato `incident:` del change hotfix + tag del patch | Fase 5 |
| **% cambios con spec activa** | `commits amparados por un change ÷ commits totales` (excepto docs/chore) | registro de spec-guard (aunque esté en `warn`, registra) | Fase 4 |
| **% por carril hotfix** | `changes hotfix ÷ changes totales` por ventana | `openspec/changes/archive/` (naming `hotfix-*`) | Fase 5 |
| **Cobertura de escenarios** | `Scenarios con test vinculado ÷ Scenarios del delta` (y acumulado sobre specs vivas) | salida JSON del CLI `spec-coverage` | Fase 3 |
| **Overrides break-glass** | recuento + motivo, por regla de `policy.yaml` | `sentinel/overrides.log` (versionado; lo escribe sentinel-guard) | Fase 1 |

Notas de implementación:

- `doctor` agrega todos los KPIs en un informe único (`doctor --kpis`), fase 4.
- Interpretación pareada (una métrica sola miente): lead time ↔ change failure rate
  (¿rápido a costa de romper?); % hotfix ↔ MTTR (¿el carril se abusa o funciona?);
  overrides ↔ regla concreta (¿qué gate estorba injustamente y hay que recalibrar?).
- Línea base: primera medición al archivar la fase 4 sobre este mismo repo (dogfooding);
  en consumidores (A/B), al mes de instalar el nivel Método.
