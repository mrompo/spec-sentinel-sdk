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
  reporta y exige revisión a posteriori. Un gate sin escape auditado acaba desinstalado. La
  vía recomendada es la llave de un solo uso `sentinel/.override`: el motivo y una línea
  `para: <acción>`, que es la que da el aviso de bloqueo. Solo la gasta la acción que nombra,
  con coincidencia exacta; en la Esclusa, `para: esclusa:<hook>` (`sentinel-paths`).
- **Leer no se bloquea**: las reglas con `skip_read_only: true` (`self-protection`,
  `managed-files`) no aplican a un comando que solo lee. La lista de lectores es cerrada, el
  comando se parte en tramos como lo parte bash (un `|` entre comillas no parte nada) y no puede
  llevar redirecciones, sustituciones, asignaciones ni opciones que escriben. Ante la duda, la
  regla aplica.
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
| **Regex evadibles** | El matching es sobre la cadena del comando; siempre habrá una grafía no prevista. Incluye las formas rebuscadas de lanzar el instalador sin nombrarlo y variantes de las asignaciones que vigila `no-hook-disabling` (revisión de `git-gates`, decisión del 2026-10-16). Las rutas del comando se resuelven a su ruta física desde la carpeta en que arranca: un `cd` previo (`cd sentinel && rm -r hooks`), una ruta montada con variables o una que se crea en el mismo comando quedan fuera (`sentinel-paths`). Las reglas del comando lo ven tal como llega, con los escapes del JSON deshechos y con cada tramo como lo ve bash (sin comillas ni escapes, y cada programa por su nombre: `/bin/mv` es `mv`); basta con que case una de las tres formas. Las palabras se leen como las vería bash: comillas, escapes y comodines (`*`, `?`, `[…]`, expandidos contra el disco); las llaves (`{sentinel,}`), `$'…'` y las sustituciones (`$(…)`) no se expanden, y un comodín que da más de 128 rutas deniega el comando | **Esclusa** y **Aduana**, que actúan sobre el resultado (el commit, la PR), no sobre la intención. Para el instalador, además: no se puede editar con las herramientas de edición y comprueba el cableado por estructura |
| **Convivencia con otros gestores de hooks** | Con husky, lefthook, el framework pre-commit o git-lfs, la Esclusa se encadena a mano en sus hooks. Esas herramientas pueden regenerarlos (y perder el encadenado), husky la lleva también a CI y su interruptor `HUSKY=0` la apaga, y el aviso de `session-start` no distingue un repo con hooks de LFS. El agente no puede editar los hooks encadenados de husky (`.husky/<hook>`) ni de `.git/hooks/`, ni la configuración de git donde vive `core.hooksPath`, pero sí los hooks de un `core.hooksPath` propio con otra ruta | Cambio OpenSpec propio, [`hook-coexistence`](../openspec/changes/hook-coexistence/proposal.md). Mientras tanto, la **Aduana** (fase 3) verá lo que se escape en local |
| **La shell que lanza el cableado** | El cableado ejecuta el Centinela con `/usr/bin/env -i`, un `PATH` fijo de carpetas del sistema (también las de NixOS) y solo `HOME`, `CLAUDE_PROJECT_DIR`, `CLAUDE_CONFIG_DIR` y `SENTINEL_OVERRIDE`. Si el Centinela falta, no se puede leer o termina con un código que no es 0 ni 2, o si `git` no responde en el proyecto (sin él no sabría la rama), el cableado sale con 2; y con `"onFailure": "block"` (Claude Code v2.1.295 o posterior), un cableado que no arranca o tarda demasiado también bloquea (`sentinel-paths`). Pero Claude Code lo lanza con `bash`, que hereda el entorno con que se arrancó Claude Code: un `BASH_ENV`, un `SHELLOPTS` o una función exportada de ese entorno actúan antes del cableado | `setup` deja pendiente un `env` en los settings de Claude Code con `SHELLOPTS`, `BASHOPTS`, `BASH_ENV` o `BASH_FUNC_*`, y los settings están protegidos; el entorno con que se arranca Claude Code es de la persona. La persona comprueba con `/hooks`. La **Esclusa** sigue actuando en cada commit |
| **Entorno de la sesión** | Un `SENTINEL_OVERRIDE` exportado al arrancar afecta a toda la sesión (el cableado lo deja pasar a propósito; el resto de `SENTINEL_*`, no). Por eso la vía recomendada es el token de un solo uso `sentinel/.override` | Auditoría: todo uso queda en `overrides.log` y es un KPI. `setup` deja pendiente un `env` en los settings de Claude Code que llega al Centinela o a git (`SENTINEL_*`, `BASH_ENV`, `GIT_CONFIG_*`, un `PATH` con entradas del repo…) y una llave que ya estaba al instalar |
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
