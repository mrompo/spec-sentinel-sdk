# Tasks — sentinel-paths

**Objetivo**: que el Centinela proteja lo que se toca (carpetas, rutas físicas, la configuración
de git real) y no el texto con que se escribe, sin bloquear trabajo legítimo, y que la llave
autorice la acción que la persona tenía en mente.
**Origen**: V5-1, V5-2, A5-3, V5-4, P5-6 y V5-7 de la quinta revisión de `git-gates`, y la deuda
del falso positivo de solo lectura de `STATUS.md`.

## Engine · antes de teclear

- [x] 0. `propose`: expediente abierto el 2026-10-18 desde la disposición de la revisión
- [ ] 0a. Gate **Intención** 👤
- [ ] 0b. `tune` → gate **Claridad**: cómo distinguir un comando que solo lee de uno que escribe
       sin un parser de shell, y cómo atar la llave a una acción sin complicar el break-glass
- [ ] 0c. `breakdown` → gate **Plan**

## Checklist

(Se escribe en `breakdown`.)
