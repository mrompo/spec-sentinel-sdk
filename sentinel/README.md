# sentinel/ — El núcleo de Shield (nivel Guardia)

Todo lo de esta carpeta es **stack-agnóstico** (shell POSIX + config declarativa) y funciona
**sin OpenSpec** (la regla `spec-guard` solo se activa en el nivel Método). Defensa en profundidad:

| Puesto | Dónde | El agente… |
|---|---|---|
| **Centinela** | `hooks/` + `policy.default.yaml` + `policy.yaml` | *no puede violar* |
| **Esclusa** | `githooks/` | *no puede commitear* |
| **Aduana** | `ci/` | *no puede mergear* |

(El puesto **Canon** —instrucciones y estándares— vive en `docs/` y `ai-specs/`. Vocabulario
completo: [`docs/05-semantica.md`](../docs/05-semantica.md).)

## Contratos clave

- **Bloqueo** (Centinela): leer el JSON del tool call por stdin (grep/sed, sin dependencias) y,
  para denegar, **exit 2 + motivo por stderr** — el agente recibe el porqué y puede corregir.
  Arquetipos: *block* / *auto-fix* / *inject* (patrón duoclaude).
- **Una política, dos ficheros**: las reglas viven en la política, no en N scripts (decisión
  plan §11). `policy.default.yaml` trae las del SDK y la actualiza `setup`; `policy.yaml` es la
  del proyecto y solo **añade** protección. En cada fichero decide la primera regla que
  matchea; entre los dos, la decisión más estricta (`block` > `confirm` > `warn`; a igualdad,
  la del SDK), así que el proyecto no puede relajar el SDK, y repetir un `id` del SDK es un
  error de política (fail-closed). `sdd:` lo declara el proyecto; si no lo hace, vale el del
  SDK (`false`).
- **Break-glass auditado** (obligatorio desde fase 1): `SENTINEL_OVERRIDE=<motivo>` permite
  saltar una regla dejando rastro (quién/cuándo/por qué) en un log versionado; `doctor` lo
  reporta y exige revisión a posteriori. Un gate sin escape auditado acaba desinstalado.
- **Skip-vs-fail** (Esclusa): "aún no instalado" = skip con aviso; "mal configurado" = fallo
  duro con la instrucción exacta de arreglo. Nunca dejar pasar sin checks por silencio.
- **El veredicto de un gate lo calcula código determinista; el LLM solo genera hallazgos.**

## Limitaciones conocidas del Centinela (honestidad de diseño)

Un hook PreToolUse es **best effort**, no una cárcel. Lo verificó un panel adversarial en la
fase 1 y estas son las fronteras reales (por eso el modelo es *defensa en profundidad*: lo que
el Centinela no puede garantizar lo cierran la Esclusa y la Aduana):

| Límite | Por qué | Quién lo cubre |
|---|---|---|
| **TOCTOU de rama** | El guard evalúa la rama *antes* de ejecutar; `git checkout main && git commit` la cambia después (mitigado: ese patrón pide confirmación) | La **Esclusa**: el `pre-push` rechaza publicar en una rama protegida, venga de donde venga el commit (SC-git-gates-05) |
| **Regex evadibles** | El matching es sobre la cadena del comando; siempre habrá una grafía no prevista. Incluye las formas rebuscadas de lanzar el instalador sin nombrarlo y variantes de las asignaciones que vigila `no-hook-disabling` (revisión de `git-gates`, decisión del 2026-10-16) | **Esclusa** y **Aduana**, que actúan sobre el resultado (el commit, la PR), no sobre la intención. Para el instalador, además: no se puede editar con las herramientas de edición y comprueba el cableado por estructura |
| **Convivencia con otros gestores de hooks** | Con husky, lefthook, el framework pre-commit o git-lfs, la Esclusa se encadena a mano en sus hooks. Esas herramientas pueden regenerarlos (y perder el encadenado), husky la lleva también a CI y su interruptor `HUSKY=0` la apaga, y el aviso de `session-start` no distingue un repo con hooks de LFS | Cambio OpenSpec propio, [`hook-coexistence`](../openspec/changes/hook-coexistence/proposal.md). Mientras tanto, la **Aduana** (fase 3) verá lo que se escape en local |
| **Hook ausente = fail-open** | Si el fichero del hook no existe, el harness recibe exit 127, que no bloquea. Mitigado con la regla `self-protection` (borrarlo o editarlo está bloqueado) | La **Aduana**: CI verifica que el enforcement sigue en su sitio |
| **Entorno de la sesión** | Un `SENTINEL_OVERRIDE` exportado al arrancar afecta a toda la sesión. Por eso la vía recomendada es el token de un solo uso `sentinel/.override` | Auditoría: todo uso queda en `overrides.log` y es un KPI |
| **Superficie de tools** | Solo se evalúan los tools del matcher de `settings.json`; tools MCP de escritura no pasan por aquí | La **Aduana** + deny-list de permisos del harness |

La regla práctica: **el Centinela evita el 95% de los accidentes y todo el descuido; no pretende
detener a un adversario decidido con acceso a shell.** Para eso están los puestos de abajo.

Estado: Centinela (fase 1) y Esclusa (fase 2) implementados, con 19 y 16 casos en el banco; el
instalador (`ai-specs/skills/setup/`, 12 casos, uno end-to-end) cierra la fase 2. Siguiente: ci → fase 3.
