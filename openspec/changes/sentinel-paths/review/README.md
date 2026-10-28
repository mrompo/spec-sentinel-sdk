# Revisión adversarial — `sentinel-paths` (las tres PRs)

**Fecha**: 2026-10-28 · **Alcance**: `git diff bf64f5a cacbe86` (22 ficheros: PRs #9 a #13) contra
los deltas de `specs/` · **Método** (`docs/05-semantica.md` §Tribunal): tres lentes con contexto
limpio (ven el diff y la spec, no `tasks.md` ni el razonamiento del implementador), una ronda
`counter-review` en la que cada lente vota los hallazgos de las otras dos, y el veredicto
calculado por código: [`synthesis.sh`](synthesis.sh) sobre los `findings-*.json` y
`votes-*.json` de esta carpeta (`bash synthesis.sh .` reproduce `verdict.json`).

- **Auditor** y **Pragmatist** reprodujeron sus hallazgos con scripts en clones desechables:
  bash 3.2 y awk de BSD en macOS y, en Docker, Debian 12 (mawk) y Alpine 3.20 (busybox). El banco
  sale en verde en las tres (hooks 28/28, githooks 16/16); ningún hallazgo lo cubre hoy un caso.
- **Adversary**: un filtro de seguridad cortó su parte práctica, como en `git-gates`, y se relanzó
  en solo lectura de código. En el `counter-review`, el Auditor y el Pragmatist reprodujeron
  V1, V2, V3, V4 y V6; V5 solo en el guard (no se pudo ver en qué carpeta lanza Claude Code el
  hook), y el Pragmatist vota en contra.

## Veredicto: `HOLD`

Regla: un hallazgo está **validado** si lo sostienen ≥2 lentes; su severidad efectiva es la
menor entre la de su lente y la más alta que le dan las que lo apoyan.
`HOLD` ← algún bloqueante validado · `CONDITIONAL` ← algún grave validado o un bloqueante sin
validar · `SHIP` ← el resto.

Lo produce **V1** (bloqueante para Adversary y Auditor; grave para el Pragmatist, porque la
Esclusa sigue actuando en cada commit). Los 26 hallazgos están validados: 1 bloqueante,
8 graves, 12 menores y 5 retoques. P1, bloqueante para su lente, queda en grave (las otras dos:
bloquea de más, no abre ninguna vía).

## Hallazgos validados, por tema

| # | Tema | Hallazgos | Qué falla | Arreglo que proponen las lentes |
|---|---|---|---|---|
| 1 | Lo que mira la regla no es lo que ejecuta bash | **V1** 🛑, V2, P8 = V7, A5, V6 | Las `command_re` miran el JSON sin decodificar: con un salto de línea o un tabulador escritos como escape delante del verbo, `mv sentinel/githooks`, `rm -rf sentinel` y `git config --remove-section core` pasan con 0 (SC-01, SC-03). El verbo se reconoce por su grafía: `/bin/mv`, `\mv`, `'mv'` pasan (SC-01). Al revés, «solo lee» parte por `\|` también entre comillas y no admite `2>/dev/null` junto a un separador (SC-08); `printf -v` cuenta como lectura | Evaluar las reglas del comando sobre las palabras ya decodificadas por `cmd_words`: el verbo de cada tramo, sin comillas ni escapes y reducido a su `basename`; partir los tramos con el mismo lector de comillas |
| 2 | La configuración de git sin nombrarla | A2, A3 = V3 | `git config remove-section core`, `rename-section` y `edit` (sin guiones, git ≥ 2.46) pasan; `core.hookspath` en otra caja, `include.PATH`, `--config-env=include.path=…` y `GIT_CONFIG_KEY_0=include.path` también, y git acaba viendo `core.hooksPath=/dev/null` (SC-03) | Subcomandos con y sin guiones, claves sin distinguir mayúsculas, `=` como frontera |
| 3 | Carpetas y ruta física | A1, P2, A4, A7, V5 | Copiar o mover a la carpeta que contiene un fichero protegido (`cp …/config .git`, `sentinel/adapters`, `sentinel/githooks/lib`) pasa. Con los worktrees dentro del repo bare, `canon()` nombra todo como `.git/<wt>/…` y `mv .claude` pasa (SC-01). La carpeta común de git se calcula desde el `cwd` del hook, no desde el proyecto. En Write/Edit, `enlace/../x` se resuelve como texto. El guard no lee el `cwd` del payload (V5: 2 de 3) | Las carpetas que contienen enforcement en `dir_re` (o `destino/basename` del origen); en `canon()` gana el prefijo más largo; `git -C "$REPO_ROOT_DIR"`; la ruta física antes de quitar `..` |
| 4 | El cableado en el uso real | P1, P3, P6 = A9 | El `PATH` fijo no encuentra un `git` de usuario (Git Bash `/mingw64/bin`, NixOS con home-manager, linuxbrew): se bloquea todo, `Read` incluido, y `setup` dice ✓ porque su prueba de humo no pasa por el cableado. En una rama sin el SDK, el `git checkout -- sentinel/hooks` que propone el mensaje falla. Con *dubious ownership* el mensaje dice «Instala git» | Buscar git en rutas de sistema por plataforma o fijar en `setup` el git absoluto; prueba de humo con el cableado real; mensajes que distinguen sin git / sin repo / rama sin SDK (con el stderr de git); que la spec (SC-09) recoja el bloqueo sin git |
| 5 | La llave | P4 = A6, V4 | La llave «lista para copiar» no se puede pegar: el terminador del heredoc va sangrado (y en la Esclusa es `LLAVE  )`), la shell se queda esperando (SC-05, SC-git-gates-11). Con `SENTINEL_OVERRIDE` activo se borra también la llave atada a otra acción | Bloque sin sangría o un `printf` de una línea, y un caso que ejecuta lo copiado; borrar la llave solo si el motivo salió de ella |
| 6 | Falsos positivos y coste | P5 = A8, P7, P9 | El tope de 128 rutas cuenta toda palabra con `/`, también en un heredoc o un `git add` largo, y deniega antes de mirar la llave: nada lo salva y el README no lo dice. `protect-enforcement-dirs` decide sobre el comando entero (`ls .claude && rm -f x`, `cp -r .claude /tmp/bk`). Entre 30 y 90 ms más por llamada, hasta +0,6 s con 60 rutas | Contar solo rutas que importan (existen, salen de un comodín o siguen a un verbo); `dir_re` por tramo; cachear la ruta física por carpeta |
| 7 | Documentación | A10 | `STATUS.md` dice «3/3 en la Aduana»; el comentario de `sc-28` remite a un límite que ya no se llama así | Al día |

## Disposición (gate **Resolución** 👤)

Decidida por una persona el 2026-10-28:

- **Se arregla en este cambio** (temas 1 a 5 y 7, y del tema 6 el tope de 128 rutas, P5 = A8),
  en una segunda ronda de `apply` con PRs pequeñas desde `main` (slices R1-R8 de `tasks.md`).
  V5 entra con el tema 3 aunque lo sostienen 2 de 3 lentes: leer el `cwd` del payload cuesta
  poco y quita la duda.
- **Deuda** en `STATUS.md`: `protect-enforcement-dirs` decide sobre el comando entero (P7) y el
  coste por llamada con muchas rutas (P9).
- Al terminar, **panel de confirmación** (tres lentes nuevas, contexto limpio) antes del
  `archive`.
