> **Orden de implementación: 01/01** — única capability de esta fase (tasks §Checklist).

# sentinel-guard — Delta spec

## ADDED Requirements

### Requirement: Evaluación de la política

El hook `sentinel-guard` SHALL leer cada tool call (JSON por stdin) y evaluar las reglas de
`sentinel/policy.yaml` en orden; la primera regla que matchea decide el resultado.

#### Scenario: Acción sin regla — pasa (SC-sentinel-guard-01)

- **WHEN** la acción no matchea ninguna regla de la política
- **THEN** el hook sale con exit 0 y la acción se ejecuta

#### Scenario: Política ilegible — fail-closed (SC-sentinel-guard-02)

- **WHEN** `policy.yaml` no existe o no parsea
- **THEN** el hook deniega (exit 2) explicando cómo arreglar la política — nunca pasa en silencio

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

Con `SENTINEL_OVERRIDE=<motivo>` el hook SHALL permitir la acción bloqueada y registrar
`timestamp · id de regla · acción · motivo` en `sentinel/overrides.log` (fichero versionado).

#### Scenario: Override con motivo (SC-sentinel-guard-08)

- **WHEN** una acción bloqueada se relanza con `SENTINEL_OVERRIDE="hotfix INC-123"`
- **THEN** la acción se ejecuta y `overrides.log` gana una línea con regla, acción y motivo

#### Scenario: Override sin motivo — sigue bloqueado (SC-sentinel-guard-09)

- **WHEN** `SENTINEL_OVERRIDE` está vacío o no definido
- **THEN** la acción bloqueada sigue bloqueada

### Requirement: Tier-awareness

Las reglas marcadas `requires_sdd` SHALL aplicarse solo cuando `tiers.sdd: true` en la política.

#### Scenario: Tier 0 — spec-guard inactivo (SC-sentinel-guard-10)

- **WHEN** `tiers.sdd: false` y el agente edita `src/**` sin cambio OpenSpec activo
- **THEN** la regla `spec-guard` no aplica (otras reglas siguen aplicando)

### Requirement: Hooks auxiliares

`session-start` SHALL inyectar al inicio de sesión la rama actual y el cambio OpenSpec activo;
`post-edit` SHALL formatear cada fichero editado con el comando `format` del adaptador de
stack, degradando en silencio si el entorno no está listo.

#### Scenario: Contexto al arrancar (SC-sentinel-guard-11)

- **WHEN** arranca una sesión de agente en el repo
- **THEN** el agente recibe rama actual + cambio activo (o "entre fases") sin pedirlo

#### Scenario: Autoformato con entorno caído (SC-sentinel-guard-12)

- **WHEN** `post-edit` corre y el comando `format` del adaptador no está disponible
- **THEN** no falla ni bloquea: degrada en silencio y la edición queda intacta
