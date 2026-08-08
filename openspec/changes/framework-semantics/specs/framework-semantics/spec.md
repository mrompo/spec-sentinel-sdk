> **Orden de implementación: 01/01** — única capability de esta fase (tasks §Checklist).

# framework-semantics — Delta spec

## ADDED Requirements

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
