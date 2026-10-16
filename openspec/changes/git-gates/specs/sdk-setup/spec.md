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
- **AND** también sin `jq`: si `.claude/settings.json` ya tiene el cableado del SDK, no se
  escribe el fragmento ni queda nada pendiente

### Requirement: La configuración del consumidor no se pisa

`setup` SHALL preservar la configuración existente del consumidor. Para fusionar
`.claude/settings.json` SHALL usar `jq` si está instalado; si no lo está, o si la fusión no es
segura, SHALL dejar `sentinel/settings.fragment.json` con la instrucción manual y no
sobrescribir nada. Siempre SHALL crear un backup antes de tocar un fichero existente.

#### Scenario: Repo con configuración previa (SC-sdk-setup-03)

- **WHEN** se instala en un repo que ya tiene `.claude/settings.json` con hooks propios y `jq`
  está disponible
- **THEN** los hooks previos se conservan, se crea un backup y los del SDK se añaden

#### Scenario: Sin jq (SC-sdk-setup-04)

- **WHEN** se instala en un repo con `.claude/settings.json` previo y `jq` no está instalado
- **THEN** el fichero queda intacto, se escribe `sentinel/settings.fragment.json` y la salida
  explica el paso manual

#### Scenario: Actualizar el cableado (SC-sdk-setup-09)

- **WHEN** se reinstala sobre un `.claude/settings.json` con el cableado de una versión anterior
  del SDK (otro matcher, el comando escrito de otra forma) o con hooks propios en el mismo grupo
- **THEN** las entradas del SDK se reconocen por la ruta de su script y se sustituyen por las
  actuales, una sola vez cada una, con backup y conservando todo lo del consumidor
- **AND** si la forma del fichero no permite fusionar con seguridad, se deja el fragmento y
  queda pendiente (exit 3), nunca un error a mitad de instalación

#### Scenario: El instalador no sirve para descablear (SC-sdk-setup-10)

- **WHEN** `setup` se ejecuta con un `jq` que no produce el cableado del SDK, o con un `jq` que
  está dentro del repo destino (por `SENTINEL_SETUP_JQ` o por el `PATH`)
- **THEN** `.claude/settings.json` conserva el cableado del Centinela: el `jq` del repo se ignora
  y un resultado sin el cableado no se escribe (queda pendiente)

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
  (`./sentinel/githooks`, con barra final o ruta absoluta) cuenta como activo

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
