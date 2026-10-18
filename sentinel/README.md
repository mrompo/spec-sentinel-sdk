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
  del proyecto y solo **añade** protección. De todas las reglas que matchean, en los dos
  ficheros, gana la decisión más estricta (`block` > `confirm` > `warn`; a igualdad, la
  primera, y las del SDK van antes), así que el proyecto no puede relajar el SDK, y repetir un
  `id` del SDK es un error de política (fail-closed). `sdd:` lo declara el proyecto; si no lo
  hace, vale el del SDK (`false`).
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
| **Convivencia con otros gestores de hooks** | Con husky, lefthook, el framework pre-commit o git-lfs, la Esclusa se encadena a mano en sus hooks. Esas herramientas pueden regenerarlos (y perder el encadenado), husky la lleva también a CI y su interruptor `HUSKY=0` la apaga, y el aviso de `session-start` no distingue un repo con hooks de LFS. El agente no puede editar los hooks encadenados de husky (`.husky/<hook>`) ni de `.git/hooks/`, ni la configuración de git donde vive `core.hooksPath`, pero sí los hooks de un `core.hooksPath` propio con otra ruta | Cambio OpenSpec propio, [`hook-coexistence`](../openspec/changes/hook-coexistence/proposal.md). Mientras tanto, la **Aduana** (fase 3) verá lo que se escape en local |
| **Hook ausente = fail-open** | Si el fichero del hook no existe, el harness recibe exit 127, que no bloquea. Mitigado con la regla `self-protection` (borrarlo o editarlo está bloqueado) | La **Aduana**: CI verifica que el enforcement sigue en su sitio |
| **Entorno de la sesión** | Un `SENTINEL_OVERRIDE` exportado al arrancar afecta a toda la sesión. Por eso la vía recomendada es el token de un solo uso `sentinel/.override` | Auditoría: todo uso queda en `overrides.log` y es un KPI. `setup` deja pendiente un `env` con `SENTINEL_*` en los settings de Claude Code |
| **jq manipulado** | `setup` lee, fusiona y comprueba `.claude/settings.json` con jq. Un jq de fuera del repo manipulado para falsear también la comprobación puede dejar el cableado sin efecto, igual que un `git` o un `bash` manipulados (revisión de `git-gates`, decisión del 2026-10-18) | `setup` ignora un jq que viva en el repo, también a través de un enlace, y dice cuál usa. La persona comprueba con `/hooks`; la **Aduana** verá lo que se escape en local |
| **Sesión en un subdirectorio** | Claude Code toma el `.claude/settings.json` del directorio en el que se abre, no el de la raíz del repo: abierto en un paquete de un monorepo, no carga ni el Centinela ni `session-start` | La guía y la skill piden abrirlo en la raíz y comprobar con `/hooks`. La **Esclusa** sigue actuando en cada commit |
| **Configuración gestionada** | `setup` lee el `managed-settings.json` de la plataforma (`allowManagedHooksOnly`, `disableAllHooks`), pero no ve la configuración que llega por MDM o desde el servidor, que también puede impedir los hooks del proyecto | La persona comprueba con `/hooks` en una sesión nueva; lo resuelve quien administra esa configuración |
| **Windows** | El SDK y `setup` son bash: funcionan con Git Bash o WSL, y el `.gitattributes` (del SDK y del consumidor) mantiene en LF lo que ejecuta bash. Windows nativo no está soportado de forma oficial (plan §11) | La **Esclusa** falla cerrada si algo llega con CRLF: rechaza, no deja pasar |
| **Esquema de Claude Code** | Un `.claude/settings.json` que es JSON válido pero no valida el esquema de Claude Code (un tipo equivocado en cualquier clave) no se carga entero, Centinela incluido. `setup` comprueba la gramática, el cableado, `disableAllHooks` y `env`, no el esquema completo | Claude Code avisa al arrancar; la persona comprueba con `/hooks` en una sesión nueva |
| **Superficie de tools** | Solo se evalúan los tools del matcher de `settings.json`; tools MCP de escritura no pasan por aquí | La **Aduana** + deny-list de permisos del harness |

La regla práctica: **el Centinela evita el 95% de los accidentes y todo el descuido; no pretende
detener a un adversario decidido con acceso a shell.** Para eso están los puestos de abajo.

Estado: Centinela (fase 1) y Esclusa (fase 2) implementados, con su banco de pruebas en
`fixture/`; el instalador (`ai-specs/skills/setup/`, con un caso end-to-end) cierra la fase 2.
Siguiente: ci → fase 3.
