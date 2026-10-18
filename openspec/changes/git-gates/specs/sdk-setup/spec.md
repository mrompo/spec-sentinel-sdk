> **Orden de implementación: 02/02** — tras `git-gates`: instala la Esclusa y el Centinela
> (tasks §Checklist, slices 6-8).

# sdk-setup — Delta spec

## ADDED Requirements

### Requirement: Instalación de un comando

La skill `setup` SHALL instalar el nivel Guardia completo en un repo ajeno con una sola
invocación: copia del enforcement, `core.hooksPath`, cableado del Centinela en
`.claude/settings.json` y detección de stack. SHALL ser idempotente.

#### Scenario: Tras instalar, los gates bloquean (SC-sdk-setup-01)

- **WHEN** se instala el nivel Guardia en un repo limpio y se intenta un commit con mensaje no
  conforme o una acción prohibida por la política
- **THEN** ambos se rechazan — la instalación es efectiva sin pasos manuales adicionales

#### Scenario: Reinstalar no cambia nada (SC-sdk-setup-02)

- **WHEN** se ejecuta `setup` dos veces seguidas en el mismo repo
- **THEN** la segunda ejecución no modifica ningún fichero ni duplica entradas en
  `.claude/settings.json`

### Requirement: La configuración del consumidor no se pisa

`setup` SHALL preservar la configuración existente del consumidor. SHALL exigir `jq` (como la
Esclusa exige gitleaks) y leer, fusionar y comprobar con él `.claude/settings.json`, con la
semántica con que lo carga Claude Code. Si la fusión no es segura, SHALL dejar
`sentinel/settings.fragment.json` con la instrucción manual y no sobrescribir nada. Siempre
SHALL crear un backup antes de tocar un fichero existente.

#### Scenario: Repo con configuración previa (SC-sdk-setup-03)

- **WHEN** se instala en un repo que ya tiene `.claude/settings.json` con hooks propios y `jq`
  está disponible
- **THEN** los hooks previos se conservan, se crea un backup y los del SDK se añaden

#### Scenario: Sin jq (SC-sdk-setup-04)

- **WHEN** se ejecuta `setup` y no hay `jq` fuera del repo destino
- **THEN** termina con exit 1 sin escribir nada, y la salida da la instrucción de instalación
  de `jq`

#### Scenario: Actualizar el cableado (SC-sdk-setup-09)

- **WHEN** se reinstala sobre un `.claude/settings.json` con el cableado de una versión anterior
  del SDK (otro matcher, el comando escrito de otra forma) o con hooks propios en el mismo grupo
- **THEN** las entradas del SDK se reconocen por la ruta de su script y se sustituyen por las
  actuales, una sola vez cada una, con backup y conservando todo lo del consumidor
- **AND** si la forma de `hooks` no permite fusionar con seguridad, queda pendiente (exit 3)
  nombrando el evento con la forma inesperada, nunca un error a mitad de instalación; corregida
  esa forma, la siguiente ejecución fusiona

#### Scenario: El instalador no sirve para descablear (SC-sdk-setup-10)

- **WHEN** `setup` se ejecuta con un `jq` que está dentro del repo destino (por
  `SENTINEL_SETUP_JQ` o por el `PATH`, también como enlace del repo a un binario de fuera), con
  una configuración de jq de la persona (`~/.jq`) que cambia lo que hacen sus programas, o con
  un `jq` cuya fusión pierde el cableado, lo saca de su evento, cambia algo fuera de `.hooks` o
  devuelve algo que no es JSON válido
- **THEN** `.claude/settings.json` conserva el cableado del Centinela: el `jq` del repo se ignora
  (se usa otro del `PATH`, si lo hay), jq se ejecuta sin la configuración de la persona y un
  resultado de la fusión que no pasa la comprobación no se escribe (queda pendiente)
- **AND** la comprobación es de estructura: cada grupo de cada evento del cableado del SDK tiene
  que estar, tal cual, en su evento; no basta con que los textos aparezcan en otro sitio
- **AND** el fichero se lee como lo carga Claude Code (con `JSON.parse`: de una clave repetida
  vale la última aparición). Uno que no es JSON válido no cuenta como cableado, tampoco con lo
  que `jq` acepta y JSON no (`NaN`, `Infinity`, números como `01`, `+1`, `.5` o `5.`, una marca
  BOM, bytes NUL o de control dentro de una cadena): queda pendiente, diciendo que no es JSON
  válido y dónde (la línea), sin proponer sustituir entradas
- **AND** un `jq` de fuera del repo manipulado para falsear también la comprobación es el límite
  documentado «jq manipulado», no parte de esta garantía

#### Scenario: El cableado es efectivo (SC-sdk-setup-14)

- **WHEN** `.claude/settings.json`, `.claude/settings.local.json` o la configuración de usuario
  de Claude Code (`$CLAUDE_CONFIG_DIR/settings.json`, por defecto `~/.claude/settings.json`)
  tienen `disableAllHooks` con un valor que no es `false`, o un `env` con variables `SENTINEL_*`,
  con las que cambian cómo arranca bash (`BASH_ENV`, `ENV`, `SHELLOPTS`, `BASHOPTS`) o con
  `CLAUDE_PROJECT_DIR`
- **THEN** `setup` termina con exit 3 nombrando el fichero y la clave: con `disableAllHooks`
  Claude Code no ejecuta ningún hook (y con un valor que no es booleano puede no cargar el
  fichero entero), y esas variables llegan al proceso del Centinela y le cambian la política, la
  llave o el código que ejecuta
- **AND** si alguno de esos ficheros existe y no se puede leer como JSON válido, queda pendiente
  («no se puede comprobar»), nunca se da por bueno
- **AND** la configuración gestionada de la organización (el `managed-settings.json` de la
  plataforma), si existe, también se lee: con `allowManagedHooksOnly: true` o un
  `disableAllHooks` que no es `false`, Claude Code no ejecuta los hooks del proyecto y queda
  pendiente, para que lo resuelva la organización
- **AND** una fusión no puede introducir ninguna de las dos claves (SC-sdk-setup-10)

#### Scenario: Lo personal no se versiona (SC-sdk-setup-15)

- **WHEN** se instala en un repo cuyo git no lee el ignore global donde Claude Code excluye
  `.claude/settings.local.json` (p. ej. con un `core.excludesFile` propio)
- **THEN** el `.gitignore` del repo excluye `.claude/settings.local.json`, además de la llave y
  los backups, y el `git add` que propone `setup` no lo incluye
- **AND** se comprueba con git (`git check-ignore`), no buscando la línea: si una regla
  posterior la anula, queda pendiente
- **AND** si `.claude/settings.local.json` ya está versionado, queda pendiente con el comando
  que lo saca del índice (`git rm --cached`), que ejecuta la persona

#### Scenario: Finales de línea (SC-sdk-setup-16)

- **WHEN** el SDK o el repo del consumidor se clonan con conversión a CRLF (Git for Windows por
  defecto, `core.autocrlf=true`)
- **THEN** lo que ejecuta bash o lee el Centinela llega con LF: el SDK trae un `.gitattributes`
  y `setup` añade al del consumidor `sentinel/** text eol=lf`; en ese clon, el Centinela deja
  pasar lo inocuo y la Esclusa acepta un commit conforme
- **AND** si la copia del SDK desde la que se ejecuta tiene ficheros distribuidos con CRLF,
  `setup` termina con 1 sin escribir nada y lo dice

#### Scenario: El nivel Método se avisa (SC-sdk-setup-17)

- **WHEN** se instala en un repo con `openspec/` (la política del consumidor tiene `sdd: true`) y
  `openspec validate --all --strict` falla
- **THEN** `setup` termina con exit 3 diciendo que el `pre-push` exigirá esa validación y que
  `sdd: false` en `sentinel/policy.yaml` la desactiva (lo decide una persona)
- **AND** sin el CLI de OpenSpec lo dice como aviso: la Esclusa omite la validación con aviso

#### Scenario: Actualización sin pisar la política (SC-sdk-setup-05)

- **WHEN** se reinstala o actualiza el SDK en un repo cuya `policy.yaml` fue personalizada
- **THEN** la política del consumidor se conserva intacta y solo se actualiza la distribuida
  (`policy.default.yaml`)

#### Scenario: Git hooks previos del consumidor (SC-sdk-setup-08)

- **WHEN** se instala en un repo que ya usa otros git hooks (`core.hooksPath` propio o global,
  husky, o hooks en el directorio de hooks de git)
- **THEN** `setup` no cambia `core.hooksPath` ni esos hooks, termina con «pasos pendientes»
  (exit 3) y da las líneas que encadenan la Esclusa **al principio** de `commit-msg`,
  `pre-commit` y `pre-push` en los hooks fuente (con husky, `.husky/<hook>`): conservan las refs
  de stdin para el resto del hook y no afectan a los repos que no tienen la Esclusa
- **AND** con esas líneas puestas, la Esclusa rechaza lo mismo que sola (p. ej. un push a
  `main`) y la siguiente ejecución de `setup` reconoce el encadenado y termina con 0
- **AND** si ese `core.hooksPath` no tiene hooks en este repo (p. ej. uno global relativo cuya
  carpeta no existe aquí), lo dice y da el comando que activa la Esclusa, en vez de proponer
  encadenar hooks que no existen
- **AND** un `core.hooksPath` que ya apunta a la Esclusa escrito de otra forma
  (`./sentinel/githooks`, con barra final, ruta absoluta o con `~`) cuenta como activo

### Requirement: La instalación avisa de lo que no puede resolver sola

`setup` SHALL detectar el stack y proponer el adaptador sin aplicarlo, y SHALL comprobar las
herramientas obligatorias de la Esclusa en el momento de instalar, no en el primer commit.
Cuando queda un paso manual, SHALL terminar con exit 3 («instalado, con pasos pendientes») y
nunca con éxito silencioso.

#### Scenario: Stack detectado, no aplicado (SC-sdk-setup-06)

- **WHEN** se instala en un repo Node o Laravel sin `sentinel/adapters/stack.yaml`
- **THEN** se escribe `sentinel/adapters/stack.proposed.yaml` con lo detectado y no se crea
  `stack.yaml`: lo activa una persona tras revisarlo. Si `stack.yaml` ya existe, no se propone nada

#### Scenario: gitleaks ausente al instalar (SC-sdk-setup-07)

- **WHEN** se instala en una máquina sin gitleaks
- **THEN** la instalación se completa, la salida da la instrucción de instalación de gitleaks
  y `setup` termina con exit 3

#### Scenario: Lo que hay que versionar no está ignorado (SC-sdk-setup-11)

- **WHEN** el `.gitignore` del repo ignora algo que la instalación necesita versionar (la
  bitácora, las políticas, `.claude/settings.json`, el enforcement)
- **THEN** `setup` termina con exit 3 nombrando cada fichero, la regla que lo ignora y la
  excepción que hay que añadir; cuando ya no están ignorados, termina con 0
- **AND** se comprueba todo lo que instala (también la librería de la Esclusa), no una muestra,
  y la excepción propuesta funciona aunque la regla venga de fuera del repo (`core.excludesFile`)
- **AND** la excepción para `.claude/` reincluye `.claude/settings.json` sin esconder lo que el
  equipo comparte en `.claude/` (comandos, agentes, skills)
- **AND** si el repo tiene `core.fileMode=false`, avisa de que los ejecutables hay que marcarlos
  en el índice (`git add --chmod=+x`) hasta que lo estén: sin el permiso, git ignora los hooks

#### Scenario: El Centinela instalado funciona (SC-sdk-setup-12)

- **WHEN** al terminar, el Centinela instalado deniega una acción inocua de shell, de lectura o
  de edición (p. ej. una política del consumidor ilegible, con una regla sin `mode:` o con una
  regex inválida)
- **THEN** `setup` termina con exit 3 y muestra el motivo que da el Centinela

#### Scenario: Desde la skill expuesta con un enlace (SC-sdk-setup-13)

- **WHEN** se ejecuta `setup.sh` a través de un enlace simbólico a la carpeta de la skill (el que
  propone la guía, `~/.claude/skills/spec-sentinel-setup`)
- **THEN** encuentra el SDK real e instala igual que ejecutado desde el SDK
