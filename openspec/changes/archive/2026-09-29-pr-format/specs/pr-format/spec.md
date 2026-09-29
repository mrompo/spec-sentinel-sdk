> **Orden de implementación: 01/01** — única capability del cambio (tasks §Checklist).

# pr-format — Delta spec

## ADDED Requirements

### Requirement: Título conforme

El título de toda PR SHALL seguir Conventional Commits (`tipo(ámbito): descripción`).

#### Scenario: Título no conforme (SC-pr-format-01)

- **WHEN** una PR se titula `Cambios de la semántica`
- **THEN** es un defecto de formato: el título esperado es del tipo
  `docs(semantics): framework vocabulary`

### Requirement: Cuerpo con secciones fijas

El cuerpo de toda PR SHALL contener, en este orden, las secciones Expediente, Posición en el
Loop, Qué cambia y por qué, Escenarios, Qué NO cambia, Verificación, Riesgos y vuelta atrás,
Excepciones y deuda, Procedencia y Foco de la revisión. Una sección que no aplica SHALL
quedarse con `N/A — <motivo>`, nunca borrarse.

#### Scenario: La plantilla tiene todas las secciones (SC-pr-format-02)

- **WHEN** se ejecuta el banco
- **THEN** `.github/pull_request_template.md` contiene las diez secciones; si falta alguna, el
  banco falla nombrándola

#### Scenario: Sección borrada en vez de N/A (SC-pr-format-03)

- **WHEN** una PR omite una sección porque "no aplica"
- **THEN** es un defecto de formato: la sección debe estar con `N/A — <motivo>`

### Requirement: Toda PR nace de un expediente

El cuerpo de una PR SHALL enlazar el expediente OpenSpec del que sale. Solo están exentas las
PRs `chore(release): …` y los back-merges entre ramas de entorno.

#### Scenario: PR sin expediente (SC-pr-format-04)

- **WHEN** una PR de `feat`, `fix` o `docs` no enlaza ningún expediente
- **THEN** es un defecto: nada entra en `main` sin su cambio OpenSpec

#### Scenario: PR exenta (SC-pr-format-05)

- **WHEN** la PR es `chore(release): 1.2.0` o un back-merge de `production` a `development`
- **THEN** la sección Expediente puede quedarse con `N/A — release` o `N/A — back-merge`

### Requirement: Escenarios trazados

Si el expediente tiene delta spec, la PR SHALL listar cada id `SC-*` del delta con el test o
check que lo cubre, o con el motivo explícito de por qué aún no lo tiene.

#### Scenario: Escenario sin rastro (SC-pr-format-06)

- **WHEN** el delta tiene `SC-x-03` y la tabla de Escenarios de la PR no lo menciona
- **THEN** es un defecto: el revisor no puede saber si está cubierto

### Requirement: Excepciones y procedencia declaradas

La PR SHALL declarar los usos de la llave que contiene (líneas añadidas a la bitácora) y SHALL
declarar su procedencia: qué hizo un agente (y con qué modelo) y qué una persona.

#### Scenario: Override sin declarar (SC-pr-format-07)

- **WHEN** el diff de la PR añade líneas a `sentinel/overrides.log` y la sección Excepciones
  dice `ninguna`
- **THEN** es un defecto: toda excepción usada debe estar a la vista del revisor

#### Scenario: Procedencia ausente (SC-pr-format-08)

- **WHEN** la sección Procedencia está vacía o con `N/A`
- **THEN** es un defecto: la procedencia nunca es "no aplica"; como mínimo, "sin agente"
