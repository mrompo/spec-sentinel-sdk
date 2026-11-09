# Panel — `sdk-version` (PRs 1/2 y 2/2)

**Fecha**: 2026-11-09 · **Alcance**: `git diff 352d986 6c5716d` (la #26 y la #27), sin
`tasks.md`, contra los deltas de `specs/` · **Método** (`docs/05-semantica.md` §Tribunal): tres
lentes con contexto limpio.

- Cada lente trabajó en su propia copia de `6c5716d`, sin historia y con `tasks.md` vacío. Vio
  el diff, los deltas, la propuesta y la documentación, nunca el razonamiento del implementador.
- Después hubo una ronda `counter-review`: cada lente votó los hallazgos de las otras dos.
- El veredicto lo calcula el código: [`synthesis.sh`](synthesis.sh), y `bash synthesis.sh .`
  reproduce `verdict.json`.

Cada hallazgo y cada voto lleva su script de reproducción, ejecutado en macOS con bash 3.2. En
la copia del Auditor, el banco sale en verde (hooks 33/33, githooks 16/16, install 20/20): los
defectos están en lo que el banco no prueba.

## Veredicto: `CONDITIONAL`

Regla: un hallazgo está **validado** si lo sostienen ≥2 lentes, y su severidad efectiva es la
menor entre la de su lente y la más alta que le dan las que lo apoyan.
`HOLD` ← algún bloqueante validado · `CONDITIONAL` ← algún grave validado o un bloqueante sin
validar · `SHIP` ← el resto.

Hay 20 hallazgos y 19 validados:
- ningún bloqueante;
- 4 graves, A1, P1, P2 y P3, los cuatro con las tres lentes a favor;
- 12 menores;
- 3 retoques.

V4 no está validado: el Auditor y el Pragmatist votan en contra, porque el hueco es anterior a
este cambio. Quitando los repetidos (A1 = P1 = V7, A4 = V2, A6 = V6), los 19 validados son 16
defectos distintos.

## Hallazgos validados, por tema

| # | Tema | Hallazgos | Qué falla | Arreglo que proponen las lentes |
|---|---|---|---|---|
| 1 | La copia sin git | **A1** (grave), **P1** (grave), V7 | Desde una copia sin git (un ZIP, una copia vendorizada, un clon de otro usuario con *dubious ownership*), `setup` solo se niega si ya hay `.sdk-version`. En un repo sin él instala sin `--downgrade` y escribe `dirty=no` sin saberlo (SC-03, SC-01). Después registra `commit=desconocido`, que no sabe leer: toda instalación posterior, también para cerrar los pendientes o desde un clon limpio y más nuevo, se niega diciendo que el fichero «no se puede leer» y aconseja `git pull` | Sin git, `why` siempre, también sin `.sdk-version`, y `dirty=desconocido`. Leer `commit=desconocido` como un estado conocido: desde un clon de git limpio, instalar con aviso, como sin fichero. El mensaje según la causa: sin git, «clona el SDK con git». `sc-18` instala desde una copia sin git y tendrá que ajustarse |
| 2 | La limpieza de la copia | **P2** (grave), A2 | Cualquier fichero sin versionar en la copia del SDK (`.idea/`, `.vscode/`) cuenta como cambios y bloquea toda instalación, sin decir cuáles, con el texto de «copia vieja» y un `git pull` que no sirve. Al revés, con `status.showUntrackedFiles=no` o con ficheros ignorados dentro de `sentinel/`, instala contenido que no está en el commit y lo registra como limpio (SC-04) | Medir la limpieza solo sobre lo que se distribuye y sin depender de la configuración: `git status --porcelain --untracked-files=all --ignored -- <rutas distribuidas>`, y nombrar en el mensaje los ficheros con cambios |
| 3 | La instalación anterior a `sdk-version` | **P3** (grave), V5 | En un repo instalado antes de este cambio (todos los que hay), `--activate` falla porque falta `.sdk-version` y manda a «instálalo con setup», que reinstala sin comprobar desde la copia que tenga el compañero y le deja el enforcement cambiado en su clon. Y sin `.sdk-version`, `setup` lo toma por primera instalación aunque la historia del repo ya lo tuvo | Si lo único que falta es `.sdk-version`, decir que es una instalación anterior y dar `git config core.hooksPath sentinel/githooks` (o el encadenado); «instálalo con setup» solo cuando no hay instalación. V5: mirar la historia de `.sdk-version` |
| 4 | El cableado que da por bueno `--activate` | A4 = V2, A5 | `--activate` acepta el Centinela con cualquier matcher (`Read`, `Glob`) y con un comando que solo nombra el script (`true …`, `… \|\| true`): la prueba de humo solo comprueba que deja pasar lo inocuo. `sc-20` no falsifica que no toque `.gitattributes` ni que exija `post-edit.sh` y `session-start.sh` en su evento (mutantes M1 y M2) | Un matcher que cubra Bash, Edit y Write; en la prueba de humo, una acción que tiene que bloquearse, en `setup` y en `--activate`. Los dos casos que faltan en `sc-20` |
| 5 | `.sdk-version` que no es un fichero | A6, V6 | Si es una carpeta, cuenta como «no constaba»: sustituye el enforcement sin `--downgrade` y muere al escribir. Si es un enlace simbólico, `setup` lo sigue y escribe fuera del repo | Decidir por existencia (`-e` o `-L`); lo que no es un fichero normal se rechaza diciendo qué es |
| 6 | Mensajes y documentación | P4, P5, A3, P6, P7 | Clon superficial: dice «más vieja o de otra rama» y propone `git pull`, no `git fetch --unshallow` (P4). Hooks commiteados sin bit de ejecución: el permiso local se mira antes que el modo en git y la pista `git add --chmod=+x` no sale (P5). Con `core.fileMode=false` y otra versión de la copia, `--activate` pide marcar un fichero que el clon no tiene (A3). Una copia anterior al cambio responde «no existe el directorio --activate» (P6). `SKILL.md` no conoce `--activate` ni `--downgrade` (P7) | El motivo propio del clon superficial; el modo en git primero; con `--activate`, la lista del clon y sin el bucle de `core.fileMode`; una frase en el aviso y en la guía; `SKILL.md` con `--activate` y con que `--downgrade` lo decide la persona |
| 7 | Ascendencia y contenido | V1, V3 | «Más nueva» se decide por ascendencia, no por contenido: un `git revert` local en la copia del SDK se instala sin `--downgrade` (V1; el Auditor vota en contra: es la decisión 1 de la Intención). `--activate` comprueba que los ficheros están, no que sean los del commit registrado (V3) | V1: pedir `--downgrade` si el HEAD de la copia no está publicado, o enseñar el `diff --stat` de `sentinel/`. V3: comparar con el commit de `.sdk-version` si la copia lo tiene |

**Sin validar**: V4. `sentinel/githooks` se activa entero, y un hook añadido (`post-checkout`)
que la política no protege se ejecutaría en cada clon. El hueco del patrón es anterior al cambio.

## Disposición (gate **Resolución** 👤)

Decidida por una persona el 2026-11-09:
- **Se arregla en este cambio**, en una ronda 2 de dos PRs desde `main`, después de mergear la
  #27:
  - **La copia del SDK**: temas 1, 2 y 5 (A1 = P1 = V7, P2 + A2, A6 = V6) y P4;
  - **Activar**: P3, A4 = V2, A5, P5, A3, P6 y P7.
- **Deuda**: V1, V3 y V5 en `STATUS.md`; V4, sin validar y anterior al cambio, también, para
  su propio cambio.
- Después, un **panel corto** de confirmación con tres lentes nuevas, y se archiva.
