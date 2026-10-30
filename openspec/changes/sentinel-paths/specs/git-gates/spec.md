# git-gates — Delta spec (sentinel-paths)

## MODIFIED Requirements

### Requirement: Excepción auditada (break-glass)

Todo rechazo de la Esclusa SHALL poder saltarse **solo** con una excepción auditada, la misma que
usa el Centinela: la llave (`sentinel/.override` con un motivo y su `para:`, **de un solo uso**)
o `SENTINEL_OVERRIDE` con un motivo en el entorno de la sesión. La llave SHALL atarse a un hook:
solo la gasta el rechazo del hook de su `para:` (`para: esclusa:<hook>`), y una llave atada a
otra acción (de la Esclusa o del Centinela) SHALL conservarse. Cada uso SHALL registrarse en la
bitácora (`sentinel/overrides.log`) con fecha, hook, qué se rechazaba y motivo. Si la bitácora no
se puede escribir, la excepción SHALL denegarse y la llave SHALL conservarse. Un motivo vacío o
solo de espacios SHALL NOT valer como excepción. La llave SHALL poder crearla solo una persona:
el Centinela SHALL impedir que el agente la escriba.

#### Scenario: Rechazo saltado con la llave (SC-git-gates-11)

- **WHEN** una persona escribe en `sentinel/.override` el motivo `hotfix INC-9` y
  `para: esclusa:pre-commit`, y se intenta un commit que el `pre-commit` rechazaría
- **THEN** el commit entra, la bitácora gana una línea con el hook y el motivo, y la llave
  desaparece: el siguiente rechazo vuelve a bloquear
- **AND** si el rechazo es de otro hook (`commit-msg`) o la llave está atada a una acción del
  Centinela o no tiene `para:`, el rechazo se mantiene, el mensaje da la llave de ese hook lista
  para copiar y la llave sigue en su sitio
- **AND** la llave del mensaje, copiada tal cual y pegada en bash, zsh o sh, escribe la llave;
  lleva la ruta absoluta, entrecomillada para la shell, así que pegada desde una subcarpeta, y
  aunque la ruta del repo tenga espacios o comillas, la llave va a la raíz del repo

#### Scenario: Bitácora no escribible (SC-git-gates-12)

- **WHEN** hay llave pero `sentinel/overrides.log` no se puede escribir
- **THEN** el rechazo se mantiene, el mensaje dice que sin registro no hay excepción, y la llave
  sigue en su sitio

#### Scenario: Excepción de sesión (SC-git-gates-13)

- **WHEN** la sesión se arrancó con `SENTINEL_OVERRIDE="motivo"` y la Esclusa rechazaría un push
- **THEN** el push se permite y queda registrado; con `SENTINEL_OVERRIDE` vacío, se rechaza
- **AND** una llave atada a otra acción no se gasta: la excepción sale de la sesión; la llave de
  este hook sí se gasta, porque si quedara valdría para repetir el salto sin la sesión

#### Scenario: El agente no puede crear la llave (SC-git-gates-14)

- **WHEN** el agente intenta escribir `sentinel/.override` (con Write, `echo >` o `tee`)
- **THEN** el Centinela lo bloquea: la llave solo la crea una persona desde su terminal

#### Scenario: El agente no puede desarmar la Esclusa (SC-git-gates-15)

- **WHEN** el agente intenta editar o borrar un hook de la Esclusa, su librería o el lector del
  adaptador, o ejecutar un comando con `SENTINEL_GITLEAKS_BIN=`, `SENTINEL_OPENSPEC_BIN=` o
  `SENTINEL_STACK=`
- **THEN** el Centinela lo bloquea; los ficheros del consumidor (`stack.yaml`) y la documentación
  de la Esclusa siguen siendo editables
