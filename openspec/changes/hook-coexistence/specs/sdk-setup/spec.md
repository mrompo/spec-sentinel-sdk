# sdk-setup — Delta spec (hook-coexistence)

## ADDED Requirements

### Requirement: Convivencia con otros gestores de git hooks

La Esclusa SHALL quedar activa junto a cualquier gestor de git hooks del repo (husky, lefthook,
el framework pre-commit, git-lfs) de una forma que sobreviva al ciclo de vida de esa
herramienta (regenerar sus hooks, reinstalarlos, ejecutarse en CI) sin romper sus hooks.

#### Scenario: El encadenado sobrevive a la regeneración (SC-hook-coexistence-01)

- **WHEN** lefthook o el framework pre-commit regeneran sus hooks (cambio de configuración,
  `npm install`, `pre-commit install`)
- **THEN** la Esclusa sigue ejecutándose en `commit-msg`, `pre-commit` y `pre-push`

#### Scenario: husky en CI (SC-hook-coexistence-02)

- **WHEN** un job de CI instala las dependencias de un repo con husky y hace un commit o un push
  de release
- **THEN** el comportamiento de la Esclusa en CI está definido y documentado, y no rompe la
  release sin aviso

#### Scenario: git-lfs en el clon de un compañero (SC-hook-coexistence-03)

- **WHEN** arranca una sesión en un clon con hooks de git-lfs en `.git/hooks` y la Esclusa sin
  activar
- **THEN** el aviso de arranque se dirige a la persona y propone la vía que no deja mudos los
  hooks de LFS

#### Scenario: Un hook encadenado que git no ejecutaría (SC-hook-coexistence-04)

- **WHEN** las líneas de la Esclusa están en un hook sin permiso de ejecución
- **THEN** ni `setup` ni el aviso de arranque lo dan por activo
