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

#### Scenario: Actualización sin pisar la política (SC-sdk-setup-05)

- **WHEN** se reinstala o actualiza el SDK en un repo cuya `policy.yaml` fue personalizada
- **THEN** la política del consumidor se conserva intacta y solo se actualiza la distribuida
  (`policy.default.yaml`)
