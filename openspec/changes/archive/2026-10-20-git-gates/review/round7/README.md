# Revisión adversarial, ronda 7 — `git-gates` PR 3/3 (instalación), de confirmación

**Fecha**: 2026-10-19 · **Rama**: `feature/git-gates-install` (contenido de `273c93c`, el X6 de
la ronda 7) · Mismo método que las rondas anteriores: tres lentes nuevas con contexto limpio,
`counter-review` cruzado y veredicto con [`../synthesis.sh`](../synthesis.sh). Fuera de alcance,
por decisión de la persona: lo del Centinela
([`sentinel-paths`](../../../../sentinel-paths/proposal.md)), la convivencia con otros gestores de
hooks, la versión del SDK, la tabla de límites y la deuda registrada en `STATUS.md`.

Incidencias del panel: un filtro de seguridad cortó la revisión práctica del Adversary, cuyo
hallazgo (V7-1) es de lectura y lo reprodujeron después el Auditor y el Pragmatist; el Auditor y
el Pragmatist se interrumpieron por el límite de uso de la sesión y se reanudaron desde donde
estaban.

## La ronda 6

De los 20 hallazgos, 18 resueltos según las lentes, con el banco verde en macOS y en Debian,
Ubuntu y Alpine. Siguen abiertos, por la misma clase: **P6-1** (el `openspec` de fuera ejecuta un
`node` del repo) y **A6-prev-V5-6** / **V6-1** (la lista de `env` y el `PATH` de `env`).

## Veredicto: `CONDITIONAL`

Ningún bloqueante. Los 12 hallazgos están validados. Agrupados por defecto:

| # | Defecto | Hallazgos | Severidad |
|---|---|---|---|
| 1 | Con una carpeta del repo en el `PATH`, `setup` sigue ejecutando programas del repo que no son jq ni openspec (el `bash` de la prueba de humo, el `node` del shebang de openspec, `git`): reescriben el guard y `setup` dice ✓. La foto final no cubre el enforcement copiado | A7-1 = P7-prev-P6-1, A7-3 | grave |
| 2 | Con una carpeta del repo en el `PATH` de la sesión (direnv, `npm run`), el propio Centinela ejecuta un `bash` del repo en cada acción, sin reinstalar, y `setup` no avisa | A7-2 | grave |
| 3 | El `PATH` del `env`: uno vacío no se comprueba (el hook sale con 127 o ejecuta un `./bash` del repo), y un enlace de fuera hacia el repo no se reconoce. La entrada absoluta de fuera la ven el Pragmatist como el límite «jq manipulado» y las otras dos como grave | V7-1, A7-prev-V6-1 | grave |
| 4 | La lista de `env` sigue cerrada: `GIT_COMMON_DIR` apaga la Esclusa | A7-prev-A6-prev-V5-6 | grave |
| 5 | Menores y retoques: la carpeta personal como repo de dotfiles (P7-1); falsos positivos de `LD_LIBRARY_PATH` y compañía (P7-2); `~` y el `PATH` de Windows en `env` (P7-3; el Auditor muestra que tratar `~` como relativo es lo correcto con `dash`); el `.gitignore` anidado que ignora una carpeta (A7-4); `mklink` en Git Bash (P7-4) | el resto | menores y retoques |

Las tres lentes coinciden en que los cuatro graves son la misma clase que en las rondas 5 y 6:
`setup` y el Centinela se fían del entorno de la sesión (`PATH` y `env`), que el agente puede
preparar. Los arreglos de cada ronda cierran una entrada de esa clase y el panel encuentra la
siguiente. El Auditor y el Pragmatist proponen por separado el arreglo de raíz: que `setup` limpie
su propio `PATH` al arrancar y que el cableado ejecute el Centinela con un entorno que no dependa
del de la sesión.

## Disposición (gate **Resolución** 👤)

Decidida por una persona el 2026-10-19: arreglar en esta PR lo del instalador, llevar el
comportamiento del hook a `sentinel-paths` y hacer el merge tras el banco, sin octavo panel
(ronda 8 de `apply`, slices Y1-Y5 de `tasks.md`).

- **En esta PR**: `setup` quita de su propio `PATH`, al arrancar y antes de ejecutar nada, las
  entradas vacías, relativas o que se alcanzan desde el repo, y lo dice (defecto 1); la foto
  final cubre también el enforcement copiado, las dos políticas, `.gitignore` y `.gitattributes`
  (A7-3); el `PATH` de `env` vacío o enlazado hacia el repo deja pendiente (defecto 3, salvo la
  entrada absoluta de fuera, que queda en el límite «jq manipulado»); `GIT_COMMON_DIR` y
  `GREP_OPTIONS` entran en la lista (defecto 4). Menores: la carpeta personal como repo (P7-1) y
  `mklink` en Git Bash (P7-4).
- **A `sentinel-paths`**: el defecto 2. Que el cableado ejecute el Centinela con un entorno que
  no dependa del de la sesión; mientras tanto, límite documentado («PATH de la sesión») y aviso
  de `setup` cuando el `PATH` con el que se ejecuta llega al repo.
- **Deuda**: los falsos positivos de `LD_LIBRARY_PATH` y compañía en `env` (P7-2), el `PATH` de
  Windows en `env` (P7-3) y el `.gitignore` anidado que ignora una carpeta (A7-4).
