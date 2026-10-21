# sentinel-guard Specification

## Purpose

El Centinela: el hook PreToolUse que evalúa cada acción del agente contra la política del SDK y
la del proyecto. Según la regla más estricta que coincida, la bloquea, pide confirmación humana
o avisa. Protege el propio enforcement y admite una excepción auditada de un solo uso.

## Requirements
### Requirement: Evaluación de la política

El hook `sentinel-guard` SHALL leer cada tool call (JSON por stdin) y evaluar la política
distribuida (`sentinel/policy.default.yaml`, viene con el SDK y la actualiza `setup`) y la del
consumidor (`sentinel/policy.yaml`, nunca se pisa). De todas las reglas que matchean, en las
dos políticas, SHALL ganar la decisión más estricta (`block` > `confirm` > `warn`) y, a
igualdad, la primera (las del SDK van antes que las del consumidor): ninguna regla que solo
confirma o avisa tapa un bloqueo, esté donde esté. El consumidor SHALL poder **añadir**
protección, nunca quitarla. `sdd:` SHALL leerse de la política del consumidor y, si no lo
declara, de la distribuida.

#### Scenario: Acción sin regla — pasa (SC-sentinel-guard-01)

- **WHEN** la acción no matchea ninguna regla de ninguna de las dos políticas
- **THEN** el hook sale con exit 0 y la acción se ejecuta

#### Scenario: Política ilegible — fail-closed (SC-sentinel-guard-02)

- **WHEN** `policy.default.yaml` no existe o no parsea, o `policy.yaml` existe pero no parsea
- **THEN** el hook deniega (exit 2) explicando cómo arreglar la política — nunca pasa en
  silencio. Que el consumidor no tenga `policy.yaml` es legítimo: protegen las reglas del SDK

#### Scenario: El consumidor añade reglas (SC-sentinel-guard-17)

- **WHEN** `policy.yaml` declara una regla propia que ninguna regla del SDK cubre
- **THEN** esa regla se aplica igual que una del SDK

#### Scenario: El consumidor no relaja el SDK (SC-sentinel-guard-18)

- **WHEN** `policy.yaml` declara una regla `warn` que matchea una acción que el SDK bloquea
  (p. ej. `git push --force`)
- **THEN** decide la regla del SDK: la acción se bloquea

#### Scenario: Id duplicado entre políticas (SC-sentinel-guard-19)

- **WHEN** `policy.yaml` declara una regla con el mismo `id` que una de `policy.default.yaml`
- **THEN** el hook deniega como error de política, explicando que las reglas del SDK no se
  sustituyen desde la del consumidor

#### Scenario: Un aviso del SDK no tapa un bloqueo del consumidor (SC-sentinel-guard-20)

- **WHEN** una acción matchea una regla `warn` o `confirm` del SDK y una `block` del consumidor
  (p. ej. editar `jest.config.js`, que el SDK solo avisa, o `rm -rf build`, que solo confirma)
- **THEN** la acción se bloquea por la regla del consumidor
- **AND** una regla `confirm` del consumidor gana a una `warn` del SDK

### Requirement: Modo block

Una regla con `mode: block` SHALL denegar la acción con exit 2 y el motivo por stderr.

#### Scenario: Commit en rama protegida (SC-sentinel-guard-03)

- **WHEN** el agente intenta `git commit` estando en `main`/`development`/`preproduction`/`production`
- **THEN** el hook deniega con el motivo y la instrucción de crear rama

#### Scenario: Edición de fichero gestionado (SC-sentinel-guard-04)

- **WHEN** el agente intenta editar `CHANGELOG.md`, un lockfile o `openspec/specs/**`
- **THEN** el hook deniega indicando qué tooling gestiona ese fichero

#### Scenario: Debilitar la suite de tests (SC-sentinel-guard-05)

- **WHEN** el agente intenta introducir `.skip(`/`.only(`/`xdescribe` en un fichero de test
- **THEN** el hook deniega (protect-tests)

### Requirement: Modo confirm

Una regla con `mode: confirm` SHALL impedir que la acción se ejecute sin aprobación humana
explícita.

#### Scenario: Comando destructivo (SC-sentinel-guard-06)

- **WHEN** el agente intenta `rm -rf`, `DROP TABLE` o `git reset --hard`
- **THEN** la acción no se ejecuta hasta que un humano la aprueba expresamente

### Requirement: Modo warn

Una regla con `mode: warn` SHALL dejar pasar la acción registrando un aviso visible.

#### Scenario: Regla en warn (SC-sentinel-guard-07)

- **WHEN** la acción matchea una regla con `mode: warn`
- **THEN** el hook sale con exit 0 y el aviso queda visible para el agente y el humano

### Requirement: Break-glass auditado

El hook SHALL permitir una acción bloqueada cuando exista un motivo de excepción —token de un
solo uso `sentinel/.override` (vía recomendada, no creable por el agente) o `SENTINEL_OVERRIDE`
en el entorno de la sesión— y SHALL registrar `timestamp · id de regla · acción · motivo` en
`sentinel/overrides.log`. Si el registro no puede escribirse, la excepción SHALL denegarse.

#### Scenario: Override con motivo (SC-sentinel-guard-08)

- **WHEN** una acción bloqueada se reintenta con un motivo de excepción presente
- **THEN** la acción se ejecuta y `overrides.log` gana una línea con regla, acción y motivo

#### Scenario: Override sin motivo — sigue bloqueado (SC-sentinel-guard-09)

- **WHEN** no hay motivo (variable vacía y sin token)
- **THEN** la acción bloqueada sigue bloqueada

### Requirement: El enforcement se protege a sí mismo

La política SHALL bloquear toda modificación o borrado del propio enforcement (hooks, las dos
políticas, log de overrides, cableado de la herramienta) y todo intento de desactivar los gates
(`--no-verify`, `core.hooksPath` desde un comando o editando la configuración de git, cualquier
variable `SENTINEL_*` fijada desde un comando).
Ejecutar el instalador SHALL requerir aprobación humana: reescribe el enforcement y el cableado.

#### Scenario: Desarmar el guard — bloqueado (SC-sentinel-guard-13)

- **WHEN** el agente intenta escribir o borrar `sentinel/hooks/*`, `sentinel/policy.yaml`,
  `sentinel/policy.default.yaml`, `sentinel/overrides.log`, `.claude/settings.json`, el
  instalador con las herramientas de edición (`ai-specs/skills/setup/setup.sh` y `chain.sh`,
  también por el enlace de la skill, `~/.claude/skills/spec-sentinel-setup/`; desde la shell
  pide aprobación, SC-sentinel-guard-21), el fragmento de cableado
  (`sentinel/settings.fragment.json`), los hooks donde queda encadenada la Esclusa
  (`.husky/<hook>`, `.git/hooks/`) o la configuración de git donde vive `core.hooksPath`
  (`.git/config`, la de un worktree o un submódulo, `~/.gitconfig`, `~/.config/git/config`), la
  configuración de jq de la persona que lee el instalador (`~/.jq`, no un `.jq` de un proyecto),
  ejecutar `git commit --no-verify`, tocar `core.hooksPath` desde un comando o fijar una
  variable `SENTINEL_*` en un comando (p. ej. `SENTINEL_POLICY_DEFAULT=` o `SENTINEL_SETUP_JQ=`)
- **THEN** el hook deniega la acción
- **AND** otras grafías de esas asignaciones y de `core.hooksPath` son el límite documentado
  «regex evadibles» (decisión de la persona del 2026-10-16), no parte de esta garantía

#### Scenario: Instalar es una decisión humana (SC-sentinel-guard-21)

- **WHEN** el agente ejecuta el instalador (`ai-specs/skills/setup/setup.sh`, con `bash` o
  directamente, también por la ruta del enlace de la skill que recomienda la guía,
  `~/.claude/skills/spec-sentinel-setup/`) o cualquier comando de shell que nombre el instalador
  (`setup.sh` o `chain.sh` en esas dos rutas)
- **THEN** el hook pide aprobación humana (`confirm`): la persona ve el comando antes de que se
  ejecute. Leerlo con las herramientas de lectura no la pide; escribirlo con las de edición se
  bloquea (SC-sentinel-guard-13)
- **AND** si el mismo comando incluye una acción que el SDK bloquea, se bloquea: pedir
  aprobación para instalar no rebaja ninguna otra regla
- **AND** la regla reconoce las formas habituales de lanzarlo; las rebuscadas son el límite
  documentado «regex evadibles» (la protección la dan la comprobación del cableado y que el
  instalador esté protegido)
- **AND** una skill propia del consumidor que se llame `setup` (p. ej.
  `.claude/skills/setup/setup.sh`) no es el instalador del SDK: se edita y se ejecuta sin
  aprobación

### Requirement: Robustez de la política

Una política malformada SHALL producir un error explícito, nunca permiso silencioso: sin
reglas, con una regla sin `mode:` o con una regex inválida, el hook deniega explicando el
arreglo. Los comentarios no SHALL alterar las reglas.

#### Scenario: Política degradada — fail-closed (SC-sentinel-guard-14)

- **WHEN** la política tiene `rules:` vacío, una regla sin `mode:`, una regex inválida, o un
  comentario indentado que menciona una clave
- **THEN** el hook deniega con el motivo concreto (o ignora el comentario), nunca pasa en silencio

### Requirement: Alcance del matching

Las reglas de ruta SHALL alcanzar también a los comandos de shell (que tocan ficheros sin
declarar `file_path`), y las reglas de contenido SHALL evaluarse solo sobre lo que se escribe.

#### Scenario: Ruta protegida vía shell (SC-sentinel-guard-15)

- **WHEN** el agente ejecuta `sed -i ... CHANGELOG.md` o `cat .env.production`
- **THEN** el hook deniega igual que si usara Edit

#### Scenario: Reparar un test no se bloquea (SC-sentinel-guard-16)

- **WHEN** el agente edita un test para **quitar** un `.skip(` existente
- **THEN** la acción se permite (solo se vigila lo que se escribe, no lo que se elimina)

### Requirement: Tier-awareness

Las reglas marcadas `requires_sdd` SHALL aplicarse solo cuando la política declara `sdd: true`.

#### Scenario: Tier 0 — spec-guard inactivo (SC-sentinel-guard-10)

- **WHEN** `tiers.sdd: false` y el agente edita `src/**` sin cambio OpenSpec activo
- **THEN** la regla `spec-guard` no aplica (otras reglas siguen aplicando)

### Requirement: Hooks auxiliares

`session-start` SHALL inyectar al inicio de sesión la rama actual y el cambio OpenSpec activo, y
SHALL avisar si el repo tiene la Esclusa pero en este clon no está activa ni encadenada (los git
hooks no viajan con el clon); `post-edit` SHALL formatear cada fichero editado con el comando
`format` del adaptador de stack, degradando en silencio si el entorno no está listo.

#### Scenario: Contexto al arrancar (SC-sentinel-guard-11)

- **WHEN** arranca una sesión de agente en el repo
- **THEN** el agente recibe rama actual + cambio activo (o "entre fases") sin pedirlo

#### Scenario: Autoformato con entorno caído (SC-sentinel-guard-12)

- **WHEN** `post-edit` corre y el comando `format` del adaptador no está disponible
- **THEN** no falla ni bloquea: degrada en silencio y la edición queda intacta

#### Scenario: La Esclusa inactiva en el clon se avisa (SC-sentinel-guard-22)

- **WHEN** arranca una sesión en un repo con `sentinel/githooks/` cuyo `core.hooksPath` no
  apunta a la Esclusa y cuyos hooks no la encadenan (p. ej. el clon recién hecho de un compañero)
- **THEN** el contexto de arranque avisa de que la Esclusa no está activa y da el comando que
  la activa; con la Esclusa activa (se escriba como se escriba su `core.hooksPath`, también con
  `~`) o encadenada, no avisa

