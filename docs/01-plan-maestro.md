# 01 · Plan maestro — Spec Sentinel SDK (v2)

> Plan de construcción del SDK. Parte de la visión ([`framework-contex.md`](framework-contex.md)),
> del análisis de fuentes (repo de investigación `../../spec-sentinel-research/` — docs 00 ·
> 02 · 03, ver §13) y de la revisión
> crítica del propio plan. **v2** (2026-07-27): reestructurado en tiers, equipo reducido a 7,
> hook único de política, break-glass, catálogo final de skills, roadmap reordenado y
> decisiones cerradas. **La fase 0 arranca con este documento** — el repo se desarrolla ya con
> su propio método (`openspec/`).

## 1. Tesis

specboot (C) resolvió la **distribución** portable multi-copilot del método SDD; duoclaude (A)
probó el **enforcement** (hooks que bloquean, contrato `exit 2` + stderr); el monorepo (B)
aporta la **madurez operativa** (intake real, PR lifecycle, versionado por entorno, Boost);
el ecosistema Osmani (D) aporta la **disciplina de skills verificables** — y confirma la tesis:
es el estado del arte en contenido y aun así todo es capa 1 (prompt). Ninguna fuente combina
disciplina + enforcement. Spec Sentinel es esa combinación, con seis piezas propias:

1. **Validación cruzada spec↔código como gate** — `verify` en pre-push y CI.
2. **`spec-coverage`** — la spec genera la obligación de test: matriz escenario↔test calculada
   por código determinista; un escenario sin test rompe el gate. *También CLI standalone: es la
   cuña de distribución del SDK.*
3. **Delegación atómica con contexto acotado y verificable** (manifiestos de contexto, §4).
4. **Guardrail de destructivos/aislamiento** + **break-glass auditado** (§6).
5. **Perfiles de stack completos** (patrón Laravel Boost, §3).
6. **`doctor`** — linter de coherencia del propio framework (referencias colgantes, deudas de
   hotfix, back-merges pendientes, manifiestos rotos, % de carril rápido).

Principios rectores heredados: *enforcement, no sugerencias* (A) · *process, not prose* +
*verificación con evidencia* (D) · *vendor, no reescribir* (D/Boost) · *el veredicto de un gate
lo calcula código determinista; el LLM solo genera los hallazgos* (adverse).

## 2. Tiers de adopción (el empaquetado del producto)

El SDK se adopta por capas — cada tier da valor completo por sí solo, y el core de enforcement
**no exige OpenSpec** (binding opcional):

| Tier | Qué instala | Requiere | Valor |
|---|---|---|---|
| **0 · Guardarraíles** | Hooks de agente (capa 2) + git hooks + CI gate + permissions | Nada (spec-agnóstico; 5 minutos con `setup`) | El agente ya no puede violar las reglas duras del repo |
| **1 · Ciclo SDD** | OpenSpec + skills del ciclo (intake→archive) + `spec-coverage` + `doctor` | Tier 0 | La spec es el contrato y genera la obligación de test |
| **2 · Equipo** | Subagentes (§4) + qa-plan/db-review + panel adversarial + perfiles de stack | Tier 1 | Delegación atómica con separación de poderes |

`spec-guard` (la regla "no hay código sin cambio activo") solo se activa con Tier 1 — en Tier 0
el resto de reglas funcionan sin SDD.

## 3. Arquitectura del SDK

```
spec-sentinel/
├── docs/                      # Fuente única (por consumidor): base/arch/<perfil>-standards
├── ai-specs/
│   ├── agents/                # Subagentes (§4) + manifiesto de contexto por agente
│   └── skills/                # Catálogo final (§5), Agent Skills spec, <500 líneas
├── sentinel/
│   ├── policy.yaml            # LA política de escritura/ejecución (reglas del hook único, §6)
│   ├── hooks/                 # 3 hooks: sentinel-guard · session-start · post-edit
│   ├── githooks/  ci/         # Templates capa 3 y 4
│   └── adapters/              # tracker / forge / stack (comandos + entorno-listo)
├── openspec/                  # Binding SDD (Tier 1): changes + specs + config
├── CLAUDE.md · AGENTS.md · GEMINI.md · codex.md    # symlinks → fuente única
└── .claude/ · .cursor/ …      # Cableado por herramienta
```

- **Adaptador de stack** (`sentinel.yaml`): *format · lint · tests · lint-dominio* + detección
  de "entorno listo". Hooks, git hooks y CI consumen esos comandos sin conocer el stack.
- **Perfil de stack completo** (patrón **Laravel Boost**, en producción en B): adaptador +
  guidelines versionadas + MCP de introspección (`database-schema`, `tinker`, `search-docs`…) +
  skills de paquete. El perfil Laravel se construye sobre Boost; **el perfil Node v1 solo lleva
  el adaptador de comandos** (emular Boost queda descoped, pieza futura).
- **Manifiesto de contexto por subagente**: fichero declarativo con lo que cada agente carga;
  `doctor` valida que las referencias existan. El contexto acotado deja de ser una intención.
- **Distribución de skills**: vendoring `skills-lock.json` (source + hash, patrón B); skills
  conformes a la Agent Skills spec → interoperables con el ecosistema D (`npx skills add`,
  plugin marketplace, después).

## 4. El equipo: 7 subagentes

Reglas transversales: quien implementa tiene escritura acotada; quien revisa es solo-lectura;
quien orquesta/diseña no escribe código; **cada agente declara su manifiesto de contexto**.

| Subagente | Rol | Escritura | Activación |
|---|---|---|---|
| **spec-orchestrator** | Fragmenta el cambio en tareas con dependencias; delega y consolida | ❌ solo `openspec/` | Siempre (Tier 2) |
| **intake-analyst** | Ticket/PDF/idea → spec 100% con *ambiguity gate*; propose-only | ❌ solo `openspec/` | Fase 0 |
| **software-architect** | `design.md` (alternativas + trade-offs + contratos) + ADRs; checkpoints en todo el ciclo (viabilidad, design gate, stop-the-line, CONDITIONAL arquitectónicos) | ✅ `design.md` + `docs/architecture.md` | Opt-in recomendado con >1 módulo/equipo |
| **developer** (variantes backend/frontend) | Implementa por slice con TDD; incluye el antiguo tooling-agent (mismo rol, scope por tarea) | ✅ acotada al módulo/tarea | Fases 2-4, por slice |
| **qa-engineer** | Plan de pruebas desde la spec **antes** de implementar; dueño de los tests de aceptación; audita la matriz escenario↔test | ✅ tests de aceptación/`qa/` — nunca `src/` | Fases 1-5 |
| **db-engineer** | Modelo de datos del design, migraciones seguras, `explain`/índices/N+1, consultas lentas en producción | ✅ `database/` — los rewrites en `src/` los hace el developer con su informe | **Trigger determinista**: el diff/design toca `database/**`, modelos o consultas |
| **adversarial-reviewer** | Panel `adverse` (vendorizado): Auditor · Adversary · Pragmatist **+ 4ª lente de conformidad arquitectónica** (absorbe al antiguo arch-reviewer); 2 rondas + síntesis determinista → `SHIP/CONDITIONAL/HOLD` | ❌ solo-lectura, contexto limpio | Fase 4, por PR |

- Las validaciones **mecánicas** de arquitectura (fronteras: dependency-cruiser/`arch()`) viven
  en CI, no en un agente — un subagente revisor aparte era redundante.
- Separaciones de poder: implementador/revisor · implementador/QA · diseñador/verificador.
  Stop-the-line arquitectónico y de tests: la desviación se escala, nunca se implementa y
  documenta después. `design.md` es del arquitecto (enforced por política, §6).
- El trigger determinista del db-engineer es el patrón para futuros perfiles (seguridad, i18n).
- ops queda dentro del perfil de deploy del consumidor (interfaz fina en el adaptador; la
  implementación de B —SSM/VPN— **no se generaliza**).

## 5. Catálogo final de skills (~21)

Anatomía obligatoria (D): frontmatter con triggers → When to Use → Process con checkpoints →
anti-racionalizaciones → Red Flags → **Verification con evidencia**. Una sola fuente: los
commands por herramienta se generan en la instalación. Origen detallado por skill: apéndice en
la tabla v1 (histórico git) y la investigación (research/02).

| Grupo | Skills (nombre final ← fusiona) |
|---|---|
| **Ciclo** | `spec-intake` (← opsx-refine + enrich-us + grill-me como gate) · `design` (← design-data-flow + review-specs + api-design + decision-log/ADR) · `breakdown` (← task-breakdown B + planning D; vertical slices, epic/story cards) · `apply` (← incremental + TDD D; por slice) · `verify` · `sync-specs` · `archive` · `explore` |
| **Entrega** | `commit` · `pull-request` (máquina de estados B, tracker enchufable) · `release` (multicanal por entorno, research/03; variante `N.x` como perfil) · `hotfix` (§7.2) |
| **QA / datos** | `qa-plan` (← generate-qa-plan Airzone) · `spec-coverage` (**también CLI standalone**) · `db-review` |
| **Soporte** | `debug` (← triaje D + Stop-the-Line B + Boost/observabilidad) · `worktree` · `sandbox-exec` |
| **Meta** | `setup` (instalador de tiers) · `doctor` · `writing-skills` · `docs-sync` (← update-docs + docs-drift CI) |

Extensiones de perfil (no core): `new-module`, scaffolding de entorno, skills de dominio,
`code-simplification`/`security-and-hardening`/`context-engineering` vendorizadas de D.

## 6. Guardarraíles: 4 capas + break-glass

| Capa | Mecanismo | El agente… |
|---|---|---|
| 1 · Prompt | Estándares + guidelines de perfil (Boost) + skills | *debería* cumplir |
| 2 · Tool | **`sentinel-guard`** + `session-start` + `post-edit` + deny-list | *no puede* violar |
| 3 · Git | commit-msg (bash puro) · pre-commit (gitleaks+format+static) · pre-push (tests + validate) — patrón skip-vs-fail de A | *no puede* commitear |
| 4 · CI | commitlint · gitleaks · lint · static · tests+cobertura · fronteras · verify · **spec-coverage** · revisión de datos (trigger db) · mutation *(opt-in)* — GitHub Actions primero (A y B lo usan), GitLab después | *no puede* mergear |

**Un solo hook de política, no seis**: `sentinel-guard` (PreToolUse) lee `sentinel/policy.yaml`
— tabla declarativa `patrón (ruta/comando) → regla → modo (block/confirm/warn)` que implementa
gitflow protegido, ficheros gestionados (CHANGELOG, lockfiles, specs archivadas, `design.md`
ajeno), protección de tests (`.skip`/`.only`/borrados/thresholds), spec-guard (solo Tier 1),
destructivos (`rm -rf`, `DROP`, force-push → confirmación humana) y aislamiento (credenciales/
entorno productivo; el MCP de Boost solo contra local contenerizado). Un script testeable,
contrato `exit 2` + stderr, sin dependencias; `doctor` valida la política.

**Break-glass (obligatorio desde fase 1)**: toda regla dura tiene vía de escape **auditada** —
`SENTINEL_OVERRIDE=<motivo>` registra quién/cuándo/por qué en un log versionado, exige revisión
a posteriori y `doctor` reporta los overrides. Un gate sin escape auditado acaba en un
framework desinstalado.

Arquetipos de hook (A): *block* / *auto-fix* / *inject*. Complemento blando: checkpoint/restore
antes de operaciones arriesgadas (gemini-cli-tips).

## 7. Flujo de desarrollo

**El ciclo es por-cambio en las puntas y por-slice en el centro** — las fases 2→4 forman un
bucle que cada *vertical slice* recorre de forma independiente hasta su propia PR; un cambio
son varias PRs pequeñas. Sin esto, los gates reconstruirían un mini-waterfall.

| Fase | Quién (agente) | Gate de salida | **Humano que decide** |
|---|---|---|---|
| 0 · Intake | intake-analyst + architect (viabilidad) | Ambiguity gate + checklist 100% | **Producto/PO** aprueba la spec |
| 1 · Propose | orchestrator + architect (`design.md`+ADRs) + qa-engineer (plan) + db-engineer (si trigger) | `openspec validate` + design + plan de pruebas | **Tech lead** aprueba design y breakdown |
| 2-4 · **Bucle por slice** | developer (TDD, worktree, hooks activos) → sandbox-exec → panel adversarial | Capa 2/3 + tests + spec-coverage del slice + veredicto `SHIP/CONDITIONAL/HOLD` + CI capa 4 | **Dev líder** aprueba la PR; CONDITIONAL arquitectónico → architect; desviación de design → stop-the-line |
| 5 · Release | `release` multicanal (research/03) + archive + docs-sync | semantic-release por canal; QA humana valida el canal `-b.N` | **QA** da el visto bueno a la versión de validación; **tech lead/DevOps** promociona a production |

### 7.1 QA transversal

La calidad es una propiedad de cada nivel (mecanismo + gate): spec falsable (GIVEN/WHEN/THEN,
happy+error) → plan de pruebas antes de implementar → TDD por slice + protección de tests →
**spec-coverage del delta** → lente test-engineer en el panel → qa-plan de regresión en release
+ smoke → **las specs archivadas son el contrato de regresión** (suite nightly) → el propio SDK
(tests de skills, doctor, fixture §9). `spec-coverage`: ids estables por `Scenario`,
matriz del delta calculada por script, nunca retroactiva.

**Brownfield — "spec on first touch"**: en repos existentes sin specs, la primera vez que un
cambio toca una capability sin especificar, el intake crea su spec mínima (y su escenario de
regresión). La cobertura SDD crece orgánicamente por las zonas que cambian — nunca big-bang.

### 7.2 Carril hotfix (comprime fases, no quita capas)

Incidencia con referencia obligatoria → rama `hotfix/<id>` desde `production` (paraguas si
agrupa `fix/*`; bugs de una `-b.N` → mismo carril contra `preproduction`) → diagnóstico
(`debug` + observabilidad + Boost logs) → **test que reproduce el bug + Scenario corregido**
(rojo→verde: el hotfix alimenta la regresión) → fix mínimo → `adverse --single-round --diff` +
una aprobación humana + CI rápido → patch en `production` (imagen etiquetada con la versión) →
smoke (bloquea) → **back-merge en cascada con gate** (`doctor` + job CI que compara ramas) +
deuda registrada (el architect revisa las deudas en el siguiente ciclo). La regresión completa
corre post-merge sin bloquear el deploy: detección diferida, nunca omitida. Solo commits `fix`;
`doctor` reporta el % de cambios por el carril.

## 8. MCPs y adaptadores

El core no depende de ningún MCP (fallback CLI/manual). Prioridad alta: **tracker**
(Atlassian/Jira — config declarativa por proyecto con ids de transición, patrón B), **forge CLI**
(`gh`/`glab`), **Laravel Boost** (perfil Laravel; por fase: design→introspección,
apply→`search-docs` versionado, verify→`tinker` en sandbox, hotfix→logs). Media/opcional:
observabilidad (Flare/Sentry: `list_slowest_routes`, `get_query_performance` para db-review),
Playwright y Chrome DevTools (perfil frontend), Postman/Context7. `markitdown` (CLI, no MCP)
para intake de documentos.

## 9. KPIs del framework

Definidos desde fase 0; el propio flujo genera los datos (archives, gates, doctor):

| KPI | Fuente | Pregunta que responde |
|---|---|---|
| Lead time (intake → production) | timestamps de artefactos OpenSpec + releases | ¿El método acelera o estorba? |
| Change failure rate | hotfixes/reverts vs releases | ¿Los gates evitan defectos? |
| MTTR | carril hotfix (incidencia → patch) | ¿El carril rápido funciona? |
| % cambios con spec activa | spec-guard + archives | ¿El SDD se usa o se esquiva? |
| % por carril hotfix | doctor | ¿"Todo es urgente"? (si sube: el ciclo normal es lento) |
| Cobertura de escenarios | spec-coverage | ¿La spec genera tests de verdad? |
| Overrides break-glass | log auditado | ¿Qué gates estorban injustamente? |

## 10. Roadmap v2 (dogfooding: cada fase = un cambio OpenSpec = PRs)

Validación doble en cada fase: **repo fixture** en el CI del SDK que ejecuta el ciclo completo
end-to-end (toda regla dura tiene un test que la falsifica — también las del framework) +
instalación real en A (duoclaude) y B (monorepo).

| Fase | Cambio | Entregable | Tier | DoD |
|---|---|---|---|---|
| 0 | `bootstrap-method` | Decisiones cerradas (§11) + esqueleto §3 + `openspec/` operativo + fixture base + KPIs definidos | — | El repo se desarrolla vía OpenSpec |
| 1 | `sentinel-guard` | Hook único de política + policy.yaml + session-start/post-edit + **break-glass auditado** + deny-list | 0 | Bloquea en fixture y en duoclaude; override auditado funciona |
| 2 | `git-gates` | githooks (skip-vs-fail) + commitlint + gitleaks + instalador `setup` | 0 | Tier 0 instalable en repo ajeno con un comando |
| 3 | `ci-gate` + **`spec-coverage` CLI** | Template CI (GitHub Actions; A y B lo usan) + spec-coverage como CLI standalone publicable | 0/1 | PR sin gates no mergea; un Scenario sin test rompe el fixture |
| 4 | `sdd-cycle` | Skills del ciclo (intake→archive) + binding spec-guard + `doctor` v1 + brownfield first-touch | 1 | Ciclo completo en el fixture; doctor detecta refs colgantes sembradas |
| 5 | `release-hotfix` | `release` multicanal + `hotfix` + gate de back-merge + PR template con procedencia IA | 1 | Patch de prueba llega al fixture-production en horas con su test |
| 6 | `team` | Subagentes §4 + manifiestos de contexto + qa-plan/db-review + `adverse` vendorizado + fronteras (dependency-cruiser/arch) | 2 | Ciclo §7 completo por slice con separación de poderes |
| 7 | `agent-run-audit` *(opcional)* | Perfil agent-house (`assert --min-score` en CI) | 2 | Coste/eficiencia medible por PR |

Fuera del roadmap: generalizar el deploy de B (queda interfaz fina en el adaptador) y emular
Boost en Node (pieza futura).

## 11. Decisiones

**Cerradas** (v2, con todo el contexto):

| Decisión | Cierre |
|---|---|
| Punto de partida | Repo propio (este) adoptando la estructura de C; PRs upstream de piezas agnósticas |
| Stack | Core agnóstico (shell/markdown/YAML); perfil Laravel sobre **Boost**; perfil Node v1 = solo adaptador de comandos |
| Distribución | Plantilla + instalador `setup` por tiers; skills con `skills-lock.json`; `npx skills add`/marketplace cuando se estabilice |
| Enforcement al importar | Tier 0 completo activo (incl. destructivos e isolation); spec-guard solo con Tier 1; QA en `warn` 1 semana → `block` |
| Hooks | **Un** hook de política declarativa (`policy.yaml`), no N scripts |
| Skills vs commands | Skills fuente única; commands generados en instalación |
| Forge/CI primero | **GitHub Actions** (A y B lo usan); GitLab CI como segundo template |
| Monorepo | Gates en raíz + config por paquete; un `openspec/` por unidad desplegable |
| Rigor hotfix | Gate rápido bloqueante + regresión post-merge no bloqueante con propuesta de revert; smoke bloquea |
| Modelo de release | Multicanal por entorno (research/03) por defecto; `N.x` como variante de perfil |

**Abiertas** (se cierran en su fase): publicación de `spec-coverage` (¿CLI propio o upstream a
OpenSpec? — decidir en fase 3) · política de soporte Windows (POSIX + Git Bash documentado;
revisar demanda) · segundo tracker tras Jira (Linear vs GitHub Issues — fase 6).

## 12. Riesgos vivos

- **Ceremonia percibida** → tiers (§2): Tier 0 da valor sin tocar el proceso de nadie.
- **Gates que estorban** → break-glass auditado + KPI de overrides; spec-guard/spec-coverage
  en `warn` la primera semana, solo delta, excepciones (docs/chores).
- **El agente juega contra la QA** → separación de poderes + lente test-engineer + mutation opt-in.
- **Carril hotfix como costumbre / back-merge olvidado** → referencia de incidente + solo `fix`
  + doctor % + job CI de comparación de ramas.
- **Reinventar lo que D/Boost mantienen** → vendorizar y contribuir upstream; el diferencial es
  enforcement + OpenSpec.
- **Deriva del propio framework** (lo que le pasó a B) → doctor + docs-drift + fixture e2e
  desde fase 0.

## 13. Referencias

- Visión: [`framework-contex.md`](framework-contex.md) · KPIs: [`04-kpis.md`](04-kpis.md)
- **Investigación** (repo hermano, fuera de este para no generar ruido):
  `~/Development-MacBook/spec-sentinel-research/` — `00-analisis-y-vision.md` (fuentes A/B/C) ·
  `02-fuente-d-ecosistema-osmani.md` (D) · `03-estado-gitflow-airzonecontrol.md` (gitflow B).
  En este plan se citan como research/00 · research/02 · research/03.
- A `~/Development-MacBook/duoclaude` · B `~/Development-MacBook/building-monorepo/airzonecontrol-monorepo` · C https://github.com/LIDR-academy/lidr-specboot · D https://github.com/addyosmani (agent-skills, adverse, agent-house…)
- OpenSpec: https://github.com/Fission-AI/OpenSpec · Laravel Boost: https://github.com/laravel/boost
- Historial v1 del plan (catálogos con origen pieza a pieza): historial git de este fichero.
