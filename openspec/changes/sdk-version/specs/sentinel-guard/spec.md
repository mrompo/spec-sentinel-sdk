# sentinel-guard — Delta spec (sdk-version)

## ADDED Requirements

### Requirement: La versión instalada del SDK se protege

La política SHALL proteger `sentinel/.sdk-version` como el resto del enforcement: el agente no
lo escribe ni lo borra, y leerlo no se bloquea.

#### Scenario: El agente no cambia la versión instalada (SC-sdk-version-08)

- **WHEN** el agente intenta escribir o borrar `sentinel/.sdk-version`, con las herramientas de
  edición o desde la shell
- **THEN** el hook deniega la acción, con el motivo de `self-protection`
- **AND** leerlo desde la shell (`cat sentinel/.sdk-version`) no se bloquea
