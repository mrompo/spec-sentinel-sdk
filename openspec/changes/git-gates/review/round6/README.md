# Revisión adversarial, ronda 6 — `git-gates` PR 3/3 (instalación)

**Fecha**: 2026-10-19 · **Rama**: `feature/git-gates-install` (contenido de `f0a700b`, el W6 de
la ronda 6) · Mismo método que las rondas anteriores: tres lentes nuevas con contexto limpio,
`counter-review` cruzado y veredicto con [`../synthesis.sh`](../synthesis.sh). Fuera de alcance,
por decisión de la persona: lo del Centinela
([`sentinel-paths`](../../../sentinel-paths/proposal.md)), la convivencia con otros gestores de
hooks, la versión del SDK, la tabla de límites y la deuda registrada en `STATUS.md`.

## La ronda 5

De los 21 hallazgos decididos para esta PR, 19 resueltos según las tres lentes, que lo
contrastaron con jq 1.6, 1.7.1 y 1.8.2 en macOS, Debian, Ubuntu y Alpine: `~/.jq`, bytes NUL y de
control, la línea del error, la forma de `hooks`, la excepción de `.claude/`, `settings.local.json`
versionado o negado, la configuración gestionada, `sdd: true`, el jq que escribe CRLF, los finales
de línea y el banco del escape. Siguen abiertos, más estrechos: **A5-1** (resuelto para un enlace
de fichero, no para una carpeta enlazada) y **V5-6** (la lista de variables de `env` es cerrada).

## Veredicto: `CONDITIONAL`

Ningún bloqueante. 19 de 20 hallazgos validados. Agrupados por defecto:

| # | Defecto | Hallazgos | Severidad |
|---|---|---|---|
| 1 | Un jq del repo se usa si se llega a él por una carpeta del repo que enlaza a otra de fuera (o, en macOS, por la ruta del repo escrita con otras mayúsculas): `jq_in_repo` compara la ruta física por texto, no la carpeta del repo por la que se encuentra | A6-prev-A5-1 = P6-prev-A5-1, A6-1 | grave |
| 2 | El `openspec` que ejecuta el aviso de `sdd: true` (nuevo en la ronda 6) sale del `PATH` sin descartar uno del repo y corre después de comprobar el cableado; al final nada vuelve a comprobarlo | P6-1 | grave |
| 3 | El `env` de los settings se comprueba con una lista cerrada: `PATH` (con un `bash` del repo delante) anula el Centinela y `GIT_CONFIG_*` anula la Esclusa. Antes de la primera instalación no hay Centinela, así que el agente puede escribirlo | A6-prev-V5-6, V6-1 | grave |
| 4 | Menores y retoques: la receta para pasar a LF una copia del SDK no hace nada (A6-2 = P6-2); en un clon CRLF, setup duplica líneas de `.gitignore` y `.gitattributes` (P6-3); un `.gitignore` anidado lleva a un bucle (P6-4); en Git Bash el enlace de la skill es una copia (P6-5); una llave previa a la instalación no se avisa (A6-3); dos reglas sin falsificar en el banco (A6-4); mensajes (A6-5, P6-6); los backups no se comprueban con git (A6-6); la regla de `~/.jq` bloquea un `.jq` del proyecto (P6-7); `ENV` da falsos positivos (P6-8); el `.gitignore` del propio SDK (P6-9) | el resto | menores y retoques |

No validado: **A6-7** (un punto de la deuda de `STATUS.md` quedó desfasado tras P5-4), fuera de
alcance para dos lentes.

Las tres lentes coinciden en que los tres graves son la misma clase: `setup` ejecuta o se fía de
algo que el agente puede preparar dentro del repo, o en los settings antes de la primera
instalación. Todos fallan solo si una persona reinstala con ese `PATH` o esa configuración.

## Disposición (gate **Resolución** 👤)

Decidida por una persona el 2026-10-19: arreglar en esta PR los tres graves y los menores baratos
(ronda 7 de `apply`, slices X1-X7 de `tasks.md`) y relanzar el panel para confirmar el cierre
antes del merge.

- Defecto 1: un programa del repo se reconoce por la identidad de cada carpeta de la ruta
  (`-ef`), la lógica y la física, no por el texto.
- Defecto 2: `openspec` con la misma regla que jq, y al final `setup` comprueba que los
  settings y `core.hooksPath` no han cambiado mientras se ejecutaba.
- Defecto 3: el `env` vigila también `GIT_CONFIG_*`, `GIT_DIR`, `GIT_WORK_TREE`,
  `GIT_EXEC_PATH`, `LD_PRELOAD`, `LD_LIBRARY_PATH`, `DYLD_*`, `BASH_FUNC_*` y un `PATH` con
  entradas relativas o dentro del repo; `ENV` sale de la lista (P6-8).
- Menores: la receta de CRLF (A6-2 = P6-2), líneas con CRLF (P6-3), el `.gitignore` anidado
  (P6-4), Git Bash (P6-5), la llave previa (A6-3), el banco (A6-4), los mensajes (A6-5, P6-6),
  los backups (A6-6), la regla de `~/.jq` anclada a la carpeta personal (P6-7), el `.gitignore`
  del SDK (P6-9) y, aunque no se validó, el punto desfasado de `STATUS.md` (A6-7).
