# Tasks — framework-semantics

**Objetivo**: vocabulario fijado, explicable y verificable, sin tocar comportamiento.

## Checklist

- [x] 1. `docs/05-semantica.md`: la cadena, los cuatro puestos con su límite honesto, niveles
       de adopción, artefactos, modos y lista de no-renombrados
- [x] 2. Delta spec con los escenarios de la capability (SC-framework-semantics-01..05)
- [x] 3. Check en el banco: la semántica define los 4 puestos y las superficies los usan (SC-01, 03)
- [x] 4. Aplicar los nombres en `README.md` (modelo del Loop y roadmap)
- [x] 5. Aplicar los nombres en `docs/guia-uso.md` (guardarraíles + glosario → apunta a la semántica)
- [x] 6. Modelo Loop/Stage/Step/Gate, steps y gates por stage, y el afinado como principio
- [x] 7. `STATUS.md` con vocabulario nuevo + `git-gates` marcado como aparcado
- [x] 8. Verificar que nada de comportamiento cambió (banco en verde sin tocar casos) (SC-04)
- [ ] 9. Revisión humana → merge → archive

## Notas de diseño (design gate)

- **Los nombres son el entregable a revisar.** Alternativas consideradas para los puestos:
  (a) funcionales — Guía/Guardia/Puerta/Muro: claros pero planos, no dicen *cuándo* actúan;
  (b) por momento — Intención/Acción/Registro/Integración: precisos pero abstractos, difíciles
  de usar en conversación ("lo bloqueó Acción" no suena a nada);
  (c) **elegida** — Canon/Centinela/Esclusa/Aduana: cada nombre es una imagen que ya contiene
  el comportamiento (una esclusa es una cámara de paso obligado; una aduana inspecciona lo que
  entra en territorio común), y encajan con el nombre del producto.
- Riesgo asumido: metáfora de control/frontera. Se mitiga con el tono del documento —cada
  puesto declara su límite honesto— y evitando vocabulario militar (nada de "defensa",
  "ataque", "trinchera").
- La numeración de puestos **no se retira**: el plan razona sobre la escalada 1→4 y ese
  razonamiento se perdería si solo quedaran nombres.
