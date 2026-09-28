# framework-semantics Specification

## Purpose
TBD - created by archiving change framework-semantics. Update Purpose after archive.
## Requirements
### Requirement: Vocabulario de fuente única

El framework SHALL mantener un documento único (`docs/05-semantica.md`) que define su
vocabulario: los cuatro puestos de la cadena, los niveles de adopción, los artefactos con
nombre propio y los modos. Todo término del framework SHALL definirse ahí antes de usarse en
otro documento.

#### Scenario: Los cuatro puestos están definidos (SC-framework-semantics-01)

- **WHEN** se consulta el documento de semántica
- **THEN** contiene los cuatro puestos (Canon, Centinela, Esclusa, Aduana) con su slug en
  inglés, qué es, cuándo actúa y su límite honesto

#### Scenario: Término sin definir (SC-framework-semantics-02)

- **WHEN** un documento introduce un nombre propio del framework que no está en la semántica
- **THEN** es un defecto: el nombre se define primero en `docs/05-semantica.md`

### Requirement: Modelo del Loop

La semántica SHALL definir el modelo con el que se describe el recorrido de un cambio: Loop,
Stage, Step y Gate, sin solape entre ellos; los tres stages (Engine, Tribunal, Delivery) con
sus steps, su dueño y su gate de salida; y Shield como capa transversal que no es un stage.
Todo gate SHALL declarar a qué step devuelve cuando falla.

#### Scenario: El modelo está definido (SC-framework-semantics-06)

- **WHEN** se consulta el documento de semántica
- **THEN** define Loop, Stage, Step y Gate, los stages Engine, Tribunal y Delivery con sus
  steps y gates, y Shield como transversal

#### Scenario: Gate sin camino de vuelta (SC-framework-semantics-07)

- **WHEN** un gate del Loop no tiene fila en la tabla de caminos de vuelta
- **THEN** es un defecto: un gate que no dice a dónde devuelve es un muro, no un gate

#### Scenario: Archive con dos desenlaces (SC-framework-semantics-08)

- **WHEN** se cierra un expediente
- **THEN** la semántica distingue **entregado** (la delta pasa a contrato vigente) de
  **descartado** (se archiva con su motivo)

### Requirement: Nombres en las superficies de usuario

Los documentos de cara al usuario (README y guía de uso) SHALL referirse a las piezas por su
nombre —stage, step, gate y puesto—, no solo por su número de capa o tier.

#### Scenario: README y guía usan los nombres (SC-framework-semantics-03)

- **WHEN** se leen `README.md` y `docs/guia-uso.md`
- **THEN** aparecen los nombres de los puestos y de los niveles de adopción, y enlazan a la
  semántica para la definición completa

### Requirement: La semántica no altera el comportamiento

Nombrar SHALL ser una operación puramente documental: ningún identificador de código, ruta de
fichero, id de regla ni modo de la política cambia con esta capability.

#### Scenario: El comportamiento no cambia (SC-framework-semantics-04)

- **WHEN** se aplica el vocabulario nuevo
- **THEN** el banco de pruebas sigue en verde sin modificar ningún caso existente, y
  `sentinel/policy.yaml` conserva sus ids y modos (`block`, `confirm`, `warn`)

### Requirement: Higiene de jerga

La semántica SHALL declarar explícitamente qué términos estándar de la industria no se
renombran, y SHALL justificar cada nombre nuevo como sustituto de una perífrasis recurrente.

#### Scenario: Lista de no-renombrados (SC-framework-semantics-05)

- **WHEN** se consulta la semántica
- **THEN** incluye la lista de términos que se mantienen tal cual (spec, commit, PR, hook,
  gate, CI, skill…) y la regla que limita la creación de nombres nuevos

