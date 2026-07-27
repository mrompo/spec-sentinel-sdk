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

## Limitaciones conocidas de la capa 2 (honestidad de diseño)

Un hook PreToolUse es **best effort**, no una cárcel. Lo verificó un panel adversarial en la
fase 1 y estas son las fronteras reales (por eso el modelo es *defensa en profundidad*: lo que
la capa 2 no puede garantizar lo cierran las capas 3 y 4):

| Límite | Por qué | Quién lo cubre |
|---|---|---|
| **TOCTOU de rama** | El guard evalúa la rama *antes* de ejecutar; `git checkout main && git commit` la cambia después (mitigado: ese patrón pide confirmación) | Capa 3: el `pre-commit`/`commit-msg` valida en el momento del commit, venga de donde venga |
| **Regex evadibles** | El matching es sobre la cadena del comando; siempre habrá una grafía no prevista | Capas 3 y 4, que actúan sobre el resultado (el commit, la PR), no sobre la intención |
| **Hook ausente = fail-open** | Si el fichero del hook no existe, el harness recibe exit 127, que no bloquea. Mitigado con la regla `self-protection` (borrarlo o editarlo está bloqueado) | Capa 4: CI verifica que el enforcement sigue en su sitio |
| **Entorno de la sesión** | Un `SENTINEL_OVERRIDE` exportado al arrancar afecta a toda la sesión. Por eso la vía recomendada es el token de un solo uso `sentinel/.override` | Auditoría: todo uso queda en `overrides.log` y es un KPI |
| **Superficie de tools** | Solo se evalúan los tools del matcher de `settings.json`; tools MCP de escritura no pasan por aquí | Capa 4 + deny-list de permisos del harness |

La regla práctica: **la capa 2 evita el 95% de los accidentes y todo el descuido; no pretende
detener a un adversario decidido con acceso a shell.** Para eso están las capas de abajo.

Estado: fase 1 implementada (hooks + política + break-glass auditado, 15 casos en el fixture).
Siguiente: githooks/instalador → fase 2 · ci → fase 3.
