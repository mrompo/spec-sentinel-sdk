# sdk-method — Delta spec (spec-purposes)

## ADDED Requirements

### Requirement: Toda spec viva declara su propósito

Cada spec viva de `openspec/specs/` SHALL tener en su sección `Purpose` un texto que diga para
qué sirve la capability. El «TBD» que deja `openspec archive` al crear una spec nueva SHALL
sustituirse en la misma PR del archivo, antes de que llegue a `main`.

#### Scenario: Una spec viva sin propósito no pasa el banco (SC-sdk-method-05)

- **WHEN** una spec viva tiene el `Purpose` vacío o empieza por «TBD»
- **THEN** `fixture/verify.sh` falla y nombra la spec
