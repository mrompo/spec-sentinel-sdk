# Tasks — spec-purposes

**Objetivo**: que cada spec viva diga para qué sirve y que ninguna vuelva a quedarse en «TBD».
**Origen**: la deuda del `Purpose` en `STATUS.md`.

## Engine · antes de teclear

- [x] 0. `propose`: expediente abierto el 2026-10-21
- [x] 0a. Gate **Intención** 👤: aprobada el 2026-10-21 (expediente con regla, frente a meter
       solo los textos)
- [x] 0b. `tune` → gate **Claridad**: un requisito y un escenario (SC-sdk-method-05); los
       textos de los seis `Purpose`, revisados por la persona antes del parche
- [x] 0c. `breakdown` → gate **Plan**: una sola PR, en el orden de abajo

## Checklist

- [x] 1. La delta de `sdk-method` y el check de `fixture/verify.sh`, en rojo (seis specs en
       «TBD»)
- [ ] 2. 👤 El `Purpose` de las seis specs vivas: parche `spec-purposes.patch` que aplica una
       persona con `git apply --index` (ficheros gestionados)
- [ ] 3. El banco en verde y `openspec validate --all --strict`
- [ ] 4. `STATUS.md`: la deuda del `Purpose` sale y entra la regla
- [ ] 5. `merge` a `main` (una persona) → `archive`
