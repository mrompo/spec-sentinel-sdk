> **Orden de implementación: 01/02** — la Esclusa primero; `sdk-setup` la instala después
> (tasks §Checklist, slices 1-5).

# git-gates — Delta spec

## ADDED Requirements

### Requirement: Mensajes de commit conformes

El hook `commit-msg` SHALL rechazar todo mensaje que no siga Conventional Commits, en bash
puro, sin depender de Node ni de paquetes externos.

#### Scenario: Mensaje no conforme (SC-git-gates-01)

- **WHEN** se intenta commitear con el mensaje `arreglado el bug`
- **THEN** el commit se rechaza indicando el formato esperado (`tipo(ámbito): descripción`)

#### Scenario: Mensajes exentos (SC-git-gates-02)

- **WHEN** el mensaje es un merge (`Merge branch ...`) o un `chore(release): 1.2.3`
- **THEN** el commit se acepta sin evaluarlo

### Requirement: Calidad antes del commit

El hook `pre-commit` SHALL ejecutar la detección de secretos y las comprobaciones de formato y
lint del adaptador de stack, **solo sobre los ficheros en staging**. La detección de secretos
SHALL usar gitleaks, que es **obligatorio**: si no está instalado, el entorno está mal
configurado y el commit SHALL rechazarse con la instrucción de instalación. SHALL NOT ejecutar la suite
de tests: la Esclusa se cierra en dos tiempos y los tests son del segundo (`pre-push`).

#### Scenario: Secreto en staging (SC-git-gates-03)

- **WHEN** un fichero en staging contiene una credencial detectable
- **THEN** el commit se rechaza señalando el fichero

#### Scenario: gitleaks no instalado (SC-git-gates-10)

- **WHEN** se intenta commitear en una máquina sin gitleaks
- **THEN** el commit se rechaza con la instrucción para instalarlo; no es un skip

#### Scenario: Formato o lint en rojo (SC-git-gates-09)

- **WHEN** un fichero en staging no pasa el `format --check` o el `lint` del adaptador
- **THEN** el commit se rechaza mostrando la salida del comando que falló, y los ficheros que
  no están en staging no se evalúan

### Requirement: Barrera antes de publicar

El hook `pre-push` SHALL ejecutar la suite de tests del adaptador y SHALL rechazar el push
cuando la rama de destino esté protegida, cerrando el TOCTOU que el Centinela no puede evitar.
En el nivel Método SHALL ejecutar `openspec validate --strict` si el CLI está instalado, y
omitirlo con aviso si no lo está (la Aduana de la fase 3 lo hace obligatorio).

#### Scenario: Tests en rojo (SC-git-gates-04)

- **WHEN** se intenta un push con la suite del adaptador en rojo
- **THEN** el push se rechaza mostrando el fallo

#### Scenario: Push directo a rama protegida (SC-git-gates-05)

- **WHEN** se intenta pushear directamente a `main`/`production` desde una sesión de agente
- **THEN** el push se rechaza (el commit ya existe: aquí no hay ventana de TOCTOU)

### Requirement: Degradación explícita (skip-vs-fail)

La Esclusa SHALL distinguir "herramienta no instalada" (skip con aviso visible) de "entorno mal
configurado" (fallo duro con la instrucción exacta de arreglo), y nunca SHALL pasar en silencio
sin ejecutar sus comprobaciones.

#### Scenario: Herramienta ausente (SC-git-gates-06)

- **WHEN** el adaptador declara un comando cuya herramienta no está instalada (exit 127)
- **THEN** el hook avisa de que se omite esa comprobación y continúa con las demás
  *(gitleaks no entra aquí: es obligatorio, ver SC-git-gates-10)*

#### Scenario: Entorno roto (SC-git-gates-08)

- **WHEN** el adaptador declara un comando cuyo entorno no está listo (su `env-ready` falla,
  p. ej. un contenedor parado)
- **THEN** el hook falla en duro y muestra la instrucción exacta para arreglarlo; no hace skip

### Requirement: Adaptador de stack declarativo

El proyecto consumidor SHALL declarar sus comandos (`format`, `lint`, `static`, `tests`,
`env-ready`) en un único fichero, `sentinel/adapters/stack.yaml`, y la Esclusa, la Aduana y el
Centinela SHALL consumirlos sin conocer el stack.

#### Scenario: Sin adaptador (SC-git-gates-07)

- **WHEN** no existe fichero de adaptador en el repo
- **THEN** los hooks omiten las comprobaciones dependientes del stack con aviso, sin fallar
