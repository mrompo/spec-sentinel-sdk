# Revisión adversarial, ronda 2 — `git-gates` PR 3/3 (instalación)

**Fecha**: 2026-10-16 · **Rama**: `feature/git-gates-install` @ `7bf7547` · **Alcance**:
`git diff main..7bf7547` (63 ficheros), tras la ronda 2 de `apply` que siguió al primer `HOLD`
([`../README.md`](../README.md)).

Mismo método: tres lentes nuevas con contexto limpio, `counter-review` cruzado y veredicto
calculado por [`../synthesis.sh`](../synthesis.sh) (`bash ../synthesis.sh .` lo reproduce).
Esta vez las tres reprodujeron sus hallazgos, también el Adversary (casos al estilo del banco),
y el Pragmatist con herramientas reales: husky 9.1.7, git-lfs, lefthook 2.2.2, el framework
pre-commit y Linux en Docker.

## La primera revisión

De los 21 hallazgos validados, **19 resueltos**. Siguen abiertos **A4** (un `jq` de fuera del
repo puede sacar el Centinela de `PreToolUse`: la comprobación es por texto, no por estructura)
y, en parte, **V1** (la confirmación del instalador no reconoce formas corrientes de lanzarlo).

## Veredicto: `HOLD`

Lo produce un bloqueante que ven las tres lentes (dos de ellas como bloqueante): **A2-2 = P2-1**.
Además, 8 graves distintos (10 contando duplicados), 11 menores distintos y 2 retoques, todos
validados.

| # | Tema | Hallazgos | Qué falla |
|---|---|---|---|
| 1 | Lo que hay que versionar | **A2-2 = P2-1** 🛑, P2-7, P2-10 | La comprobación del `.gitignore` mira 6 ficheros: con `lib/` (plantilla Python, `outDir` de TypeScript) la librería de la Esclusa no se versiona, `setup` sale con 0 y a los compañeros les falla todo commit. Con `core.fileMode=false` los hooks se versionan sin `+x` y git los ignora. `.claude/` en el `excludesFile` global necesita otra excepción |
| 2 | Las reglas del Centinela | A2-1 = V2-1, A2-6 = V2-prevV1, A2-5 = P2-6, V2-6 | `install-needs-human` (`confirm`) va delante de los `block` del SDK: un comando que además ejecuta (o solo nombra) `setup.sh` pasa de bloqueado a una pregunta. La regla no reconoce `cd … && bash setup.sh`, `/bin/bash` ni la ruta del symlink de la skill, que además hace fallar a `setup`. `SENTINEL_X+=` y `core.hookspath` en minúsculas pasan |
| 3 | El instalador como vía | A2-prevA4 = V2-prevA4, V2-5, V2-4, A2-3 = P2-9, A2-7 | La validación del resultado es por texto. `setup.sh`, `chain.sh` y el fragmento no están protegidos. El conteo deja exit 3 perpetuo en dos casos legítimos. La prueba de humo solo prueba `Bash` |
| 4 | Convivir con otros gestores de hooks | V2-2, V2-3, P2-2, P2-3, P2-4, P2-5, P2-8, A2-4, V2-7 | El encadenado vive en ficheros sin proteger (`.husky/<hook>`, `.git/hooks/`); lefthook y pre-commit lo regeneran y se pierde; con husky la Esclusa llega a CI y rompe las releases, y hereda `HUSKY=0`; husky antes de `npm install` deja la Esclusa apagada; el aviso de `session-start` manda activar `core.hooksPath` aunque haya hooks de LFS (rompe LFS), no mira `+x` y se dirige al agente con un comando que el Centinela le bloquea |
| 5 | Retoque | A2-8 | Un `core.hooksPath` con `~` que apunta a la Esclusa se toma por ajeno |

El tema 4 no es un fallo puntual: lo produce el diseño de la ronda 2 (encadenar la Esclusa
dentro de hooks ajenos). Cada gestor de hooks (husky, lefthook, pre-commit, git-lfs) tiene su
propio ciclo de vida y sus interruptores.

## Disposición (gate **Resolución** 👤)

Decidida por una persona el 2026-10-16:

- **Temas 1, 2, 3 y 5 se arreglan en esta PR** (ronda 3 de `apply`, slices S1-S5 de
  `tasks.md`), con otro parche de ficheros protegidos, y el panel se relanza al terminar.
- **El tema 4 pasa a un cambio OpenSpec propio** (convivencia con otros gestores de hooks, con
  su diseño). En esta PR se protegen los ficheros donde queda encadenada la Esclusa y la guía
  documenta el resto como límite conocido.
- **A2-6 = V2-prevV1** (formas de lanzar el instalador que la regla no reconoce): se documenta
  como parte del límite «regex evadibles» de `sentinel/README.md`, sin ampliar la regex. La
  protección real la dan la comprobación estructural del cableado (S3) y proteger el instalador
  (S4). Decidido por una persona el 2026-10-16.
