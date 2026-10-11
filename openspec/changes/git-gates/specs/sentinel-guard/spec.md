> **Slice 6 de `git-gates`** — la política se separa en distribuida y del consumidor (opción A,
> decidida el 2026-10-12: primero la distribuida, el consumidor solo añade).

# sentinel-guard — Delta spec

## MODIFIED Requirements

### Requirement: Evaluación de la política

El hook `sentinel-guard` SHALL leer cada tool call (JSON por stdin) y evaluar en orden primero
las reglas de la política distribuida (`sentinel/policy.default.yaml`, viene con el SDK y la
actualiza `setup`) y después las de la política del consumidor (`sentinel/policy.yaml`, nunca
se pisa); la primera regla que matchea decide el resultado. El consumidor solo SHALL poder
**añadir** reglas: ninguna suya se evalúa antes que una del SDK. `sdd:` SHALL leerse de la
política del consumidor y, si no lo declara, de la distribuida.

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

### Requirement: El enforcement se protege a sí mismo

La política SHALL bloquear toda modificación o borrado del propio enforcement (hooks, las dos
políticas, log de overrides, cableado de la herramienta) y todo intento de desactivar los gates
(`--no-verify`, `core.hooksPath`, auto-concesión de variables de override o de política).

#### Scenario: Desarmar el guard — bloqueado (SC-sentinel-guard-13)

- **WHEN** el agente intenta escribir o borrar `sentinel/hooks/*`, `sentinel/policy.yaml`,
  `sentinel/policy.default.yaml`, `sentinel/overrides.log` o `.claude/settings.json`, ejecutar
  `git commit --no-verify` o apuntar `SENTINEL_POLICY_DEFAULT=` a otra política
- **THEN** el hook deniega la acción
