# Proposal — spec-purposes (toda spec viva dice para qué sirve)

> Nace de la deuda de `STATUS.md`: las specs vivas tienen el `Purpose` en «TBD». La persona
> decidió el 2026-10-21 rellenarlo y convertir la deuda en regla.

## Why

`openspec archive` crea cada spec viva nueva con el `Purpose` en «TBD - created by archiving
change … Update Purpose after archive.», y ninguna de las seis specs vivas lo tiene rellenado:
`git-gates`, `sdk-setup`, `sentinel-guard`, `framework-semantics`, `sdk-method` y `pr-format`.
Quien llega a una spec no sabe para qué sirve la capability sin leer todos sus requisitos, y
nada impide que el próximo archivo deje otra más igual.

## What Changes

1. Requisito nuevo en `sdk-method`: toda spec viva declara su propósito. El «TBD» que deja
   `openspec archive` se sustituye antes de que el archivo llegue a `main`.
2. Un check en `fixture/verify.sh` que falla si alguna spec viva tiene el `Purpose` vacío o en
   «TBD», nombrándola (SC-sdk-method-05).
3. El `Purpose` de las seis specs vivas, con una o dos frases cada una.

## Impact

- Capability afectada: `sdk-method` (requisito nuevo).
- Ficheros: las seis specs vivas (`openspec/specs/*/spec.md`), que son ficheros gestionados: el
  agente prepara el parche y lo aplica una persona; `fixture/verify.sh`.
- Sin cambio de comportamiento del enforcement.
- Desde el merge, archivar un cambio que cree una spec viva exige rellenar su `Purpose` en la
  misma PR, o el banco falla.
