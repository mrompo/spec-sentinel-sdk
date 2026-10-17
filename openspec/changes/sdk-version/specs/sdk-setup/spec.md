# sdk-setup — Delta spec (sdk-version)

## ADDED Requirements

### Requirement: La versión del SDK instalada queda registrada

`setup` SHALL registrar en el repo, en un fichero versionado, la versión del SDK que instala, y
SHALL negarse a sustituir lo distribuido por una versión más antigua o con cambios sin
commitear sin una confirmación explícita de la persona.

#### Scenario: Instalar deja constancia de la versión (SC-sdk-version-01)

- **WHEN** se instala o se actualiza el SDK en un repo
- **THEN** queda en un fichero versionado qué versión del SDK se instaló y si su árbol tenía
  cambios sin commitear

#### Scenario: Un SDK más viejo no revierte en silencio (SC-sdk-version-02)

- **WHEN** se ejecuta `setup` desde una copia del SDK más antigua que la instalada
- **THEN** no se sustituye nada sin una confirmación explícita, y la salida dice qué versión hay
  instalada y cuál se instalaría

#### Scenario: El clon de un compañero solo activa (SC-sdk-version-03)

- **WHEN** arranca una sesión en un clon que ya tiene la instalación versionada y la Esclusa sin
  activar
- **THEN** el aviso propone activar la Esclusa, no reinstalar el SDK
