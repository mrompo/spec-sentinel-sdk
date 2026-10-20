# Revisión adversarial — `git-gates` PR 3/3 (instalación)

**Fecha**: 2026-10-16 · **Rama**: `feature/git-gates-install` @ `2879722` · **Alcance**:
`git diff main..2879722` (48 ficheros) contra los deltas de `specs/`.

**Método** (`docs/05-semantica.md` §Tribunal): tres lentes con contexto limpio (ven el diff y
la spec, nunca el razonamiento del implementador), una ronda `counter-review` en la que cada
lente vota los hallazgos de las otras dos, y un veredicto calculado por código:
[`synthesis.sh`](synthesis.sh) sobre los `findings-*.json` y `votes-*.json` de esta carpeta
(`bash synthesis.sh .` lo reproduce).

- **Auditor** (corrección y lógica) y **Pragmatist** (contacto con la realidad) reprodujeron
  cada hallazgo con scripts en repos desechables: bash 3.2 en macOS y, el Pragmatist, también
  Linux, husky v9 real, hooks de git-lfs, `core.hooksPath` global, sin jq y la plantilla
  `.gitignore` de Node.
- **Adversary** (seguridad y abuso): un filtro de seguridad cortó su parte práctica, así que sus
  hallazgos son de lectura de código. Su hallazgo principal (V1) lo reprodujo el Auditor (A4).

## Veredicto: `HOLD`

Regla: un hallazgo está **validado** si lo sostienen ≥2 lentes. Su severidad efectiva es la
menor entre la de su lente y la más alta que le dan las lentes que lo apoyan, así que un
bloqueante necesita dos lentes que lo vean bloqueante.
`HOLD` ← algún bloqueante validado · `CONDITIONAL` ← algún grave validado o un bloqueante sin
validar · `SHIP` ← el resto.

Lo produce **A1** (bloqueante para Auditor y Pragmatist). Además hay **12 graves validados**,
6 menores y 2 retoques. Camino de vuelta: `apply` (los hallazgos con `fichero:línea` están en
los JSON).

## Hallazgos validados, por tema

| # | Tema | Hallazgos | Qué falla | Arreglo que proponen las lentes |
|---|---|---|---|---|
| 1 | La instalación no se cierra | **A1** 🛑, P3, A7 | Sin jq, la 2ª ejecución no es idempotente (SC-sdk-setup-02). Tras resolver bien un pendiente, o con `hooksPath` escrito de otra forma, `setup` sale con 3 para siempre | Comprobar en vez de repetir: cableado ya presente (sin jq), encadenado ya hecho, `hooksPath` normalizado |
| 2 | Encadenar con hooks ajenos | A3, P1, P2, P4 | El consejo impreso deja la Esclusa sin bloquear (el `pre-push` pierde stdin; lo añadido tras un `exit` no corre), apunta a `.husky/_` (generado e ignorado), se pierde al reinstalar (`.git/hooks` movidos a `sentinel/githooks`) y, en un `hooksPath` global, rompe los commits de los demás repos | Snippet correcto (stdin guardado, Esclusa al principio, guarda `[ -x … ]`), husky en `.husky/<hook>`, no mover hooks a `sentinel/githooks` |
| 3 | Las dos políticas | A2 | Una regla `warn` o `confirm` del SDK decide antes que un `block` del proyecto: «puedes añadir protección» no se cumple (SC-sentinel-guard-17) | Cada política decide por primera coincidencia y gana la decisión más estricta de las dos |
| 4 | El agente usa el instalador | A4, V1, V3 | Con un jq propio (`SENTINEL_SETUP_JQ` o `PATH`), `setup` reescribe `.claude/settings.json` y descablea el Centinela; el Centinela permite el comando | Validar en bash que el resultado conserva el cableado, ignorar un jq dentro del repo, cubrir `SENTINEL_*=` en `no-hook-disabling`, `confirm` para ejecutar `setup.sh` |
| 5 | Lo que no llega al equipo | A5 = P6, P5 | Con `*.log` o `.claude/` en el `.gitignore` no se versionan la bitácora ni el cableado. `core.hooksPath` no viaja con el clon: en los compañeros la Esclusa queda apagada sin aviso | `git check-ignore` + excepciones o pendiente; paso por clon en la guía y aviso en `session-start` |
| 6 | Actualizar el cableado | P8, A8 | La fusión deduplica por cadena exacta: un matcher antiguo (sin `Read\|Grep\|Glob`) nunca se actualiza y `setup` dice «ya cableado»; formas que pasan SAFE rompen MERGE | Identificar las entradas del SDK por la ruta del script y sustituirlas; atar el fragmento al `settings.json` del SDK en el banco |
| 7 | Menores | A6, A9, P9, P10, A10 | Política del proyecto que lo deniega todo con exit 0 · ficheros tocados sin backup · «1 = nada a medias» no es cierto · la guía promete una skill que el agente no encuentra · un caso del banco que no prueba lo que dice | Ver cada JSON |

## No validados (1 de 3 lentes)

- **P7** — el proyecto ya no puede proteger sus propias ramas (`develop`, `staging`) en el
  `pre-push`. Auditor y Adversary: es el límite asumido en el slice 6, no un defecto; como
  mucho, la guía debería decirlo.
- **V2** (procedencia del SDK) y **V4** (backups sin proteger): sin impacto real según las
  otras dos lentes (V4 comprobado: los backups de ficheros protegidos ya están protegidos).

## Disposición (gate **Resolución** 👤)

Decidida por una persona el 2026-10-16:

- **Todo lo validado se arregla en esta PR** (temas 1 a 7), en una segunda ronda de `apply`
  (slices R1-R9 de `tasks.md`), y el panel se relanza al terminar.
- **P7**: se mantiene el límite de la opción A (la lista de ramas protegidas la decide el SDK) y
  la guía lo explica; ampliarla iría en un cambio aparte.
- **V2 y V4**: sin acción (no validados, sin impacto real).
