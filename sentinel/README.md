# sentinel/ — El núcleo de enforcement (Tier 0)

Todo lo de esta carpeta es **stack-agnóstico** (shell POSIX + config declarativa) y funciona
**sin OpenSpec** (la regla `spec-guard` solo se activa con Tier 1). Defensa en profundidad:

| Capa | Dónde | El agente… |
|---|---|---|
| 2 · Tool | `hooks/` + `policy.yaml` | *no puede violar* |
| 3 · Git | `githooks/` | *no puede commitear* |
| 4 · CI | `ci/` | *no puede mergear* |

(La capa 1 —prompt/estándares— vive en `docs/` y `ai-specs/`.)

## Contratos clave

- **Bloqueo** (capa 2): leer el JSON del tool call por stdin (grep/sed, sin dependencias) y,
  para denegar, **exit 2 + motivo por stderr** — el agente recibe el porqué y puede corregir.
  Arquetipos: *block* / *auto-fix* / *inject* (patrón duoclaude).
- **Política única**: las reglas viven en `policy.yaml`, no en N scripts (decisión plan §11).
- **Break-glass auditado** (obligatorio desde fase 1): `SENTINEL_OVERRIDE=<motivo>` permite
  saltar una regla dejando rastro (quién/cuándo/por qué) en un log versionado; `doctor` lo
  reporta y exige revisión a posteriori. Un gate sin escape auditado acaba desinstalado.
- **Skip-vs-fail** (capa 3): "aún no instalado" = skip con aviso; "mal configurado" = fallo
  duro con la instrucción exacta de arreglo. Nunca dejar pasar sin checks por silencio.
- **El veredicto de un gate lo calcula código determinista; el LLM solo genera hallazgos.**

Estado: esqueleto de fase 0. La lógica llega por fases: hooks → fase 1 · githooks/instalador →
fase 2 · ci → fase 3.
