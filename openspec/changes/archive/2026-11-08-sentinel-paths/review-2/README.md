# Panel de confirmación — `sentinel-paths` (ronda 2: PRs 4 a 6)

**Fecha**: 2026-10-31 · **Alcance**: `git diff cacbe86 9036d89` (PRs #15 a #18), sin `tasks.md`
ni el primer panel, contra los deltas de `specs/` · **Método** (`docs/05-semantica.md` §Tribunal),
como el [primer panel](../review/README.md): tres lentes nuevas con contexto limpio.
- Cada lente trabajó en una copia de `main` en `9036d89` sin historia y con `tasks.md` vacío, y
  vio el diff, la spec y el primer panel con su disposición.
- Cada lente hizo dos cosas: confirmar los hallazgos que debían arreglarse y buscar lo nuevo.
- Después hubo una ronda `counter-review`, en la que cada lente votó los hallazgos de las otras
  dos.
- El veredicto lo calcula el código: [`synthesis.sh`](synthesis.sh), y `bash synthesis.sh .`
  reproduce `verdict.json`.

Cada hallazgo y cada voto lleva su script de reproducción, y se ejecutaron así:
- las tres lentes, en macOS con bash 3.2;
- el Auditor y el Pragmatist, además, en Docker con Debian 12 y Alpine 3.20.

En la copia, el banco sale en verde en macOS (hooks 31/31, githooks 16/16, install 18/18). Esta
vez el Adversary completó su parte práctica.

## Veredicto: `HOLD`

Regla: un hallazgo está **validado** si lo sostienen ≥2 lentes, y su severidad efectiva es la
menor entre la de su lente y la más alta que le dan las que lo apoyan.
`HOLD` ← algún bloqueante validado · `CONDITIONAL` ← algún grave validado o un bloqueante sin
validar · `SHIP` ← el resto.

Hay 30 hallazgos y los 30 están validados, sin un solo voto en contra:
- 4 bloqueantes: A1, A2, V1 y V4;
- 7 graves;
- 11 menores;
- 8 retoques.

Los bloqueantes no tienen el mismo respaldo:
- A1 y V4 son bloqueantes para las tres lentes. Se tropieza con ellos sin buscarlos:
  `cp x/config .git 2>/dev/null` y `x="$(mv sentinel/githooks …)"`.
- A2 y V1 lo son para dos lentes. El Pragmatist los deja en graves, porque para dar con ellos hay
  que buscar el hueco a propósito.

**Confirmación del primer panel**: de los 21 hallazgos que había que arreglar, las tres lentes dan
por arreglados 15. Los otros seis quedan **a medias** para una lente:
- **A1**, para el Adversary y el Auditor: lo reabren A1 y V3;
- **V2**, para el Auditor: lo reabre A3 = V4;
- **V5**, para el Auditor: lo reabre A6;
- **P8**, para el Auditor: lo reabre A8;
- **A10**, para el Auditor: lo reabre A9;
- **P4**, para el Pragmatist: lo reabre P4.

**Respecto a la ronda 2**:
- **Regresiones de la ronda 2:** A5, P1 y P2. Son falsos positivos y coste nuevos.
- **Ya estaban antes:** según el Auditor, A2, A4 = V9 y V2 no son regresiones de la ronda 2,
  pero van contra la spec.

## Hallazgos validados, por tema

| # | Tema | Hallazgos | Qué falla | Arreglo que proponen las lentes |
|---|---|---|---|---|
| 1 | Lo que ejecuta bash, otra vez | **V4 = A3** 🛑, V6, V7, A5, A8, P10 | Una sustitución entre comillas dobles (`x="$(rm -rf sentinel)"`) y una shell anidada (`bash -c '…'`, `sh -c`, `eval`) son una sola palabra para `cmd_words`: pasan (SC-01). `<<<` y el `<<` aritmético abren un heredoc que no existe, y una comilla de dos líneas esconde el comando siguiente. `~+` y `~-` no se expanden. Al revés, los tramos «como los ve bash» quitan las comillas a todos los argumentos: un patrón que se llama como un verbo (`grep -rn "chmod" sentinel/hooks`) bloquea una lectura (regresión); un `>` entre comillas cuenta como redirección; el cuerpo de un heredoc cuenta como comandos | Leer como código el contenido de `$(…)` y de `` `…` `` dentro de comillas dobles, y volver a pasar por `cmd_words` el argumento de `bash|sh|zsh|dash -c` y de `eval` (o, como mínimo, fail-closed: `dir_re` sobre sus palabras); no abrir heredoc con `<<<` ni dentro de `$((…))`; `~+`/`~-`; en `CMD_NORM`, reducir a su nombre solo la palabra de programa de cada tramo |
| 2 | Carpetas, `.git` y la caja | **A1 = V3** 🛑, **A2** 🛑, **V1** 🛑, V5, A6, P6 | `into_dir` toma por destino la última palabra: con `cp x/config .git 2>/dev/null`, o con `--target=` abreviado, `.git/config` se sustituye y `core.hooksPath` queda en `/dev/null` (SC-01, reabre A1). `mv .git` no se bloquea: `.git` no está en `dir_re`. En APFS y NTFS, `mv Sentinel/githooks` pasa, porque la regla distingue mayúsculas y el disco no. `git restore sentinel` o `git checkout <rev> -- sentinel` borran las líneas de la bitácora que aún no están en un commit y traen una versión antigua del enforcement. El `cwd` del payload no se decodifica y, con comillas o `\` en la ruta, el guard vuelve en silencio a la carpeta del hook. Write a `sentinel\policy.yaml` pasa: queda por verificar qué ruta manda Claude Code en Windows | Marcar las redirecciones en `cmd_words` y probar como destino toda palabra no-opción que sea una carpeta; las abreviaturas de `--target-directory`; `\.git` en `dir_re`; comparar sin caja cuando el disco no la distingue; `git restore\|checkout\|stash\|reset` sobre carpetas del enforcement, y la bitácora con una copia fuera de lo que git restaura; decodificar el `cwd` (y fail-closed si no es una carpeta); decodificar `file_path` y `cygpath -u` en MSYS |
| 3 | Saltarse la Esclusa con git | V2, A4 = V9 | `git commit -n`, `-nm` y `--no-verif` se saltan pre-commit y commit-msg sin la llave. `protected-branches` no reconoce el commit detrás de `git -C .`, `git -c k=v`, `env`, `command` o una asignación: en `main` pasa (SC-03) | `--no-veri(f(y)?)?` y `-[a-zA-Z]*n` en `git commit`; opciones globales con argumento y prefijos de ejecución delante de `git`, o decidir sobre `CMD_NORM` con el subcomando |
| 4 | Falsos positivos y coste | P1, P2, P3, P9, A7 | `no-hook-disabling` no tiene `skip_read_only` y bloquea `grep -rni core.hookspath docs` (regresión). El peor caso por llamada pasa de ~1,4 s a 8-24 s, y el tope de 10000 entradas es por carpeta: la misma copia se bloquea en 0,5 s o pasa en 22 s según se escriba. `too-many-paths` bloquea lecturas (`wc -l docs/m/*`) con un motivo que engaña. `sed -n`, `awk`, `rg` y `jq` no son lectores y el motivo dice «modifica». El README dice que un heredoc no cuenta para el tope, y cuenta | `skip_read_only` en `no-hook-disabling`; presupuesto por comando y caché de `phys_dir`/`canon`; un motivo de `too-many-paths` que diga qué hacer; decir cómo leer el enforcement en el motivo; el README al día |
| 5 | La llave y la bitácora | P4, V8 | El heredoc de la llave solo cierra si se pega sin sangría (reabre P4). Con `SENTINEL_OVERRIDE`, un comando con más de 512 rutas que además borra el enforcement queda en la bitácora solo como `too-many-paths` | Llave en una línea (`printf '%s\n' '<motivo>' 'para: …' > '<ruta>'`), insensible a la sangría; evaluar las reglas también con `TOO_MANY` y registrar los dos ids |
| 6 | El cableado y sus mensajes | P5, P7, P8 | Los remedios hablan como si el agente pudiera ejecutarlos; `git checkout HEAD -- sentinel/hooks/…` falla desde una subcarpeta; sin git no dice qué hacer. El motivo llega detrás de los 2,2 KB del comando. Con un uid sin entrada en `/etc/passwd`, `id -un` escribe un error en cada llamada | «una persona, desde su terminal», `git -C '<proyecto>' …`; los diagnósticos en un script protegido; `id -un 2>/dev/null` |
| 7 | Banco y documentación | A10, A9, V10 | `sc-30` necesita perl, `sc-18` un `tar` con `--null` y `sc-28` falla como root: el banco no sale en verde en Alpine ni como root. `STATUS.md` decía que la PR 6 seguía abierta (ya corregido en esta rama). La fila «Regex evadibles» no menciona los programas que escriben por su cuenta (`tar -x`, `git apply`, `patch`) | Límite de tiempo sin perl, `git archive \| tar -x`, saltar la comprobación de escritura como root; la fila al día |

## Disposición (gate **Resolución** 👤)

Decidida por una persona el 2026-10-31: una **ronda 3 acotada**.

- **Se arregla en este cambio**, en dos PRs pequeñas desde `main` (slices R8-R11 de
  `tasks.md`):
  - los cuatro bloqueantes: V4 = A3, A1 = V3, A2 y V1;
  - los graves baratos: V6, V2 y A4 = V9;
  - las regresiones de la ronda 2 que no son de coste: A5 y P1.
- **Deuda** en `STATUS.md`:
  - lo que pide diseño o comprobarlo fuera: V5 (proteger la bitácora sin bloquear
    `git restore .`) y P6 (qué ruta manda Claude Code en Windows);
  - el coste por llamada (P2, que amplía P9);
  - los menores y retoques restantes: A6, A7, A8, A10, P3, P4, P5, P7, P8, P9, P10, V7, V8 y V10.
    A9 ya está corregido en esta rama.
- Al terminar, un **panel corto**: tres lentes con contexto limpio que solo confirman lo
  arreglado en la ronda 3, con variantes cercanas, sin buscar hallazgos nuevos.
