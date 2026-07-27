# sdk-method Specification

## Purpose
TBD - created by archiving change bootstrap-method. Update Purpose after archive.
## Requirements
### Requirement: Dogfooding del método

El repo del SDK SHALL desarrollarse mediante su propio método: todo cambio de framework tiene
su cambio OpenSpec en `openspec/changes/`, y las specs archivadas en `openspec/specs/` son el
contrato vigente del framework.

#### Scenario: Cambio con spec (SC-sdk-method-01)

- **WHEN** una fase del roadmap arranca
- **THEN** existe `openspec/changes/<fase>/` con proposal, tasks y delta spec antes de tocar
  ningún otro fichero

#### Scenario: Cambio sin spec — rechazado (SC-sdk-method-02)

- **WHEN** se intenta mergear a `main` un cambio de framework sin cambio OpenSpec activo
- **THEN** el gate lo rechaza (desde fase 1 vía sentinel-guard; hasta entonces, revisión humana)

### Requirement: Estructura portable

El esqueleto del SDK SHALL seguir la estructura del plan §3, con symlinks multi-copilot que
apunten a una fuente única de instrucciones.

#### Scenario: Fuente única (SC-sdk-method-03)

- **WHEN** se edita la instrucción raíz del agente
- **THEN** `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` y `codex.md` reflejan el cambio sin duplicar
  contenido (symlink o include)

#### Scenario: Symlink roto — detectado (SC-sdk-method-04)

- **WHEN** un symlink multi-copilot queda colgante
- **THEN** `doctor` (fase 4) lo reporta como error; hasta entonces, el fixture lo verifica

