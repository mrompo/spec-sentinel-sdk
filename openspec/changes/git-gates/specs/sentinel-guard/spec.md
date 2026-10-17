> **Slice 6 de `git-gates`** — la política se separa en distribuida y del consumidor (opción A,
> decidida el 2026-10-12: primero la distribuida, el consumidor solo añade).

# sentinel-guard — Delta spec

## MODIFIED Requirements

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

### Requirement: El enforcement se protege a sí mismo

La política SHALL bloquear toda modificación o borrado del propio enforcement (hooks, las dos
políticas, log de overrides, cableado de la herramienta) y todo intento de desactivar los gates
(`--no-verify`, `core.hooksPath`, cualquier variable `SENTINEL_*` fijada desde un comando).
Ejecutar el instalador SHALL requerir aprobación humana: reescribe el enforcement y el cableado.

#### Scenario: Desarmar el guard — bloqueado (SC-sentinel-guard-13)

- **WHEN** el agente intenta escribir o borrar `sentinel/hooks/*`, `sentinel/policy.yaml`,
  `sentinel/policy.default.yaml`, `sentinel/overrides.log`, `.claude/settings.json`, el
  instalador (`ai-specs/skills/setup/setup.sh` y `chain.sh`), el fragmento de cableado
  (`sentinel/settings.fragment.json`) o los hooks donde queda encadenada la Esclusa
  (`.husky/<hook>`, `.git/hooks/`), ejecutar `git commit --no-verify`, tocar `core.hooksPath`
  (en cualquier combinación de mayúsculas) o fijar o ampliar una variable `SENTINEL_*` en un
  comando (p. ej. `SENTINEL_POLICY_DEFAULT=` o `SENTINEL_SETUP_JQ=`)
- **THEN** el hook deniega la acción

#### Scenario: Instalar es una decisión humana (SC-sentinel-guard-21)

- **WHEN** el agente ejecuta el instalador (`ai-specs/skills/setup/setup.sh`, con `bash` o
  directamente)
- **THEN** el hook pide aprobación humana (`confirm`); leer o buscar en ese fichero no la pide
- **AND** si el mismo comando incluye una acción que el SDK bloquea, se bloquea: pedir
  aprobación para instalar no rebaja ninguna otra regla
- **AND** la regla reconoce las formas habituales de lanzarlo; las rebuscadas son el límite
  documentado «regex evadibles» (la protección la dan la comprobación del cableado y que el
  instalador esté protegido)

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
