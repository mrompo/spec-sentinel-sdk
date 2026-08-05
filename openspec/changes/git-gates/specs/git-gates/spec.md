> **Orden de implementación: 01/01** — única capability de esta fase (tasks §Checklist).

# git-gates — Delta spec

## ADDED Requirements

### Requirement: Mensajes de commit conformes

El hook `commit-msg` SHALL rechazar todo mensaje que no siga Conventional Commits, sin depender
de Node ni de paquetes externos.

#### Scenario: Mensaje no conforme (SC-git-gates-01)

- **WHEN** se intenta commitear con el mensaje `arreglado el bug`
- **THEN** el commit se rechaza indicando el formato esperado (`tipo(ámbito): descripción`)

#### Scenario: Mensajes exentos (SC-git-gates-02)

- **WHEN** el mensaje es un merge (`Merge branch ...`) o un `chore(release): 1.2.3`
- **THEN** el commit se acepta sin evaluarlo

### Requirement: Calidad antes del commit

El hook `pre-commit` SHALL ejecutar detección de secretos y las comprobaciones de formato/lint
del adaptador de stack **solo sobre los ficheros en staging**.

#### Scenario: Secreto en staging (SC-git-gates-03)

- **WHEN** un fichero en staging contiene una credencial detectable
- **THEN** el commit se rechaza señalando el fichero

### Requirement: Barrera antes de publicar

El hook `pre-push` SHALL ejecutar la suite de tests del adaptador y SHALL rechazar el push
cuando la rama de destino esté protegida, cerrando el TOCTOU que la capa 2 no puede evitar.

#### Scenario: Tests en rojo (SC-git-gates-04)

- **WHEN** se intenta un push con la suite del adaptador en rojo
- **THEN** el push se rechaza mostrando el fallo

#### Scenario: Push directo a rama protegida (SC-git-gates-05)

- **WHEN** se intenta pushear directamente a `main`/`production` desde una sesión de agente
- **THEN** el push se rechaza (el commit ya existe: aquí no hay ventana de TOCTOU)

### Requirement: Degradación explícita (skip-vs-fail)

Los git hooks SHALL distinguir "herramienta no instalada" (skip con aviso visible) de "entorno
mal configurado" (fallo duro con la instrucción exacta de arreglo), y nunca SHALL pasar en
silencio sin ejecutar sus comprobaciones.

#### Scenario: Herramienta ausente (SC-git-gates-06)

- **WHEN** gitleaks no está instalado
- **THEN** el hook avisa de que se omite esa comprobación y continúa con las demás

### Requirement: Adaptador de stack declarativo

El proyecto consumidor SHALL declarar sus comandos (`format`, `lint`, `static`, `tests`,
`env-ready`) en un único fichero, y los hooks y el CI SHALL consumirlos sin conocer el stack.

#### Scenario: Sin adaptador (SC-git-gates-07)

- **WHEN** no existe fichero de adaptador en el repo
- **THEN** los hooks omiten las comprobaciones dependientes del stack con aviso, sin fallar

### Requirement: Instalación de un comando

La skill `setup` SHALL instalar el Tier 0 completo en un repo ajeno con una sola invocación:
copia del enforcement, `core.hooksPath`, cableado de los hooks de agente y detección de stack.
SHALL preservar la configuración existente del consumidor (backup + fusión, o instrucción
manual explícita si la fusión no es segura) y SHALL ser idempotente.

#### Scenario: Repo con configuración previa (SC-git-gates-08)

- **WHEN** se instala en un repo que ya tiene `.claude/settings.json` con hooks propios
- **THEN** los hooks previos se conservan, se crea un backup y los del SDK se añaden (o se
  entrega el fragmento con la instrucción, sin sobrescribir nada)

#### Scenario: Actualización sin pisar la política (SC-git-gates-09)

- **WHEN** se reinstala o actualiza el SDK en un repo cuya `policy.yaml` fue personalizada
- **THEN** la política del consumidor se conserva intacta y solo se actualiza la distribuida

#### Scenario: Tras instalar, los gates bloquean (SC-git-gates-10)

- **WHEN** se instala el Tier 0 en un repo limpio y se intenta un commit con mensaje no conforme
  o una acción prohibida por la política
- **THEN** ambos se rechazan — la instalación es efectiva sin pasos manuales adicionales
