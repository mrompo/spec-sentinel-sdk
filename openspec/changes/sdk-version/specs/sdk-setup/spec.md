# sdk-setup — Delta spec (sdk-version)

## ADDED Requirements

### Requirement: La versión del SDK instalada queda registrada

`setup` SHALL registrar en el repo, en el fichero versionado `sentinel/.sdk-version`, el commit
de la copia del SDK que instala y si su árbol tenía cambios sin commitear. SHALL negarse a
sustituir lo distribuido por una versión que no sea igual o más nueva que la instalada, o que
tenga cambios sin commitear, salvo que la persona lo confirme con `--downgrade` en el comando.

#### Scenario: Instalar deja constancia de la versión (SC-sdk-version-01)

- **WHEN** se instala o se actualiza el SDK en un repo
- **THEN** `sentinel/.sdk-version` dice el commit de la copia del SDK y si su árbol tenía
  cambios sin commitear, y `setup` lo nombra entre lo que hay que versionar
- **AND** sobre el propio SDK, donde no se copia nada, no se escribe

#### Scenario: Una versión igual o más nueva se instala (SC-sdk-version-02)

- **WHEN** el commit de `sentinel/.sdk-version` es el de la copia del SDK o uno de sus
  antecesores, y la copia no tiene cambios sin commitear
- **THEN** `setup` instala como hasta ahora y actualiza el fichero
- **AND** en un repo sin `sentinel/.sdk-version` (la primera instalación, o una anterior a este
  cambio) también instala, y dice que no constaba versión

#### Scenario: Un SDK más viejo o dudoso no revierte en silencio (SC-sdk-version-03)

- **WHEN** se ejecuta `setup` desde una copia cuyo commit no desciende del instalado (más
  vieja o de otra rama), que no es un clon de git, o con un `sentinel/.sdk-version` que no se
  puede leer
- **THEN** `setup` no escribe nada, dice qué versión hay instalada y cuál instalaría, explica
  que se confirma con `--downgrade` y sale con error

#### Scenario: Una copia con cambios sin commitear pide confirmación (SC-sdk-version-04)

- **WHEN** la copia del SDK tiene cambios sin commitear, aunque su commit sea igual o más nuevo
- **THEN** `setup` no escribe nada, lo dice y sale con error, igual que en SC-sdk-version-03

#### Scenario: La persona confirma con --downgrade (SC-sdk-version-05)

- **WHEN** la persona ejecuta `setup --downgrade` en cualquiera de los casos anteriores
- **THEN** `setup` instala, avisa de que la versión instalada es más vieja, dudosa o con
  cambios, y `sentinel/.sdk-version` registra la que ha quedado

#### Scenario: El clon de un compañero solo activa (SC-sdk-version-06)

- **WHEN** en un clon que ya tiene la instalación versionada (con `sentinel/.sdk-version`) se
  ejecuta `setup --activate`
- **THEN** no copia ni sustituye nada: comprueba que la instalación versionada está completa y
  el cableado en `.claude/settings.json`, y activa la Esclusa o, si el repo usa otros git hooks,
  da las líneas para encadenarla, como `setup`
- **AND** si falta algo de la instalación versionada, lo dice y no activa nada

#### Scenario: El aviso de arranque propone activar (SC-sdk-version-07)

- **WHEN** arranca una sesión en un clon con `sentinel/.sdk-version` versionado y la Esclusa
  sin activar ni encadenar
- **THEN** el aviso de arranque propone `setup --activate` (o `git config core.hooksPath
  sentinel/githooks`), no reinstalar el SDK
