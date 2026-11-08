# Panel corto — `sentinel-paths` (ronda 3: PRs 7 y 8)

**Fecha**: 2026-11-03 · **Alcance**: `git diff 06d1c01 bc3a755` (PRs #20, #21 y #22), sin
`tasks.md`, contra los deltas de `specs/` · **Método** (`docs/05-semantica.md` §Tribunal), como
el [panel de confirmación](../review-2/README.md): tres lentes nuevas con contexto limpio.
- Cada lente trabajó en una copia de `main` en `bc3a755` sin historia y con `tasks.md` vacío, y
  vio el diff, la spec y el panel de la ronda 2 con su disposición.
- **Panel corto**: el encargo era solo confirmar, con variantes cercanas, los nueve hallazgos
  que la ronda 3 debía arreglar (V4 = A3, V6, A5, A1 = V3, A2, V1, V2, A4 = V9 y P1), sin buscar
  defectos nuevos fuera de ellos. Lo que la disposición dejó como deuda y la fila «Regex
  evadibles» quedaban fuera.
- Después hubo una ronda `counter-review`, en la que cada lente votó los hallazgos de las otras
  dos.
- El veredicto lo calcula el código: [`synthesis.sh`](synthesis.sh), y `bash synthesis.sh .`
  reproduce `verdict.json`.

Cada hallazgo y cada voto lleva su script de reproducción. Las tres lentes los ejecutaron en
macOS con bash 3.2, y también en Docker con Debian 12 y Alpine. En la copia, el banco sale en
verde en macOS (hooks 31/31, githooks 16/16, install 18/18).

## Veredicto: `CONDITIONAL`

Regla: un hallazgo está **validado** si lo sostienen ≥2 lentes, y su severidad efectiva es la
menor entre la de su lente y la más alta que le dan las que lo apoyan.
`HOLD` ← algún bloqueante validado · `CONDITIONAL` ← algún grave validado o un bloqueante sin
validar · `SHIP` ← el resto.

Hay 18 hallazgos y los 18 están validados por las tres lentes, sin un solo voto en contra:
- ningún bloqueante;
- 2 graves, P1 y V4, los dos en el cuerpo de un heredoc;
- 13 menores;
- 3 retoques.

Quitando los repetidos, son 11 defectos distintos.

**Confirmación de la ronda 3**: las tres lentes dan por arreglados A1 = V3, V1 y P1, que son el
destino de `cp`/`mv`, la caja y las lecturas de `no-hook-disabling`. Los otros seis quedan **a
medias** para al menos una lente:

| Id de la ronda 2 | Arreglado para | A medias para | Lo que lo reabre |
|---|---|---|---|
| V4 = A3 | Auditor, Pragmatist | Adversary | V4, V1, A7 y P1 (regresión) |
| V6 | — | las tres | A4 = V2 = P5 (`$[…]`) |
| A5 | Adversary | Auditor, Pragmatist | A3 = P2 (`grep` con alternativas) |
| A2 | Pragmatist | Auditor, Adversary | A5 = V5 (`.git/worktrees`) |
| V2 | Pragmatist | Auditor, Adversary | A1 (`-m 'x;' -n`), V3 |
| A4 = V9 | — | las tres | A2 = V3 = P3 (prefijos con argumento), P4 |

## Hallazgos validados, por tema

| # | Tema | Hallazgos | Qué falla | Arreglo que proponen las lentes |
|---|---|---|---|---|
| 1 | El cuerpo de un heredoc | **P1** (grave, regresión), **V4** (grave) | Lo que hay en `"$(…)"` se relee como comando, y con ello el cuerpo de un heredoc: `git commit -m "$(cat <<'EOF' … EOF)"`, la forma que usa Claude Code, y `gh pr create --body "$(cat <<'EOF' …)"` se bloquean en una rama feature si el mensaje nombra `mv .git` o `chmod sentinel/hooks`. Antes de la ronda 3 pasaban. Al revés, en un heredoc sin comillas en el delimitador, bash ejecuta `$(…)` aunque vaya entre comillas simples o detrás de un apóstrofo (`it's $(rm -rf sentinel)`), y el guard lee esas comillas como comillas y no lo ve (SC-sentinel-paths-01) | Con el delimitador entre comillas (`<<'EOF'`, `<<"EOF"`, `<<\EOF`), el cuerpo no cuenta como comandos ni rutas; sin comillas, el cuerpo no abre comillas y cada `$(…)` y `` `…` `` sale como código. Casos en `sc-29` en los dos sentidos |
| 2 | La Esclusa con otra grafía | A1, A2 = V3 = P3, P4 | `git commit -m 'x;' -n` se salta pre-commit y commit-msg: la regla no cruza una palabra que acaba en `;`, `&` o `\|`. Un prefijo cuya opción lleva argumento (`sudo -u root`, `env -u X`, `timeout -s KILL`, `stdbuf -o L`, `exec -a g`) o un alias en el propio comando (`git -c alias.ci=commit ci`) esconde el `git commit` en `main` (el pre-push sigue parando el push). `git -C` a otro worktree decide con la rama de la sesión | En el tramo, cambiar `;&\|` por `_` dentro de una palabra; las opciones con argumento de cada prefijo; la rama con `git -C <carpeta> symbolic-ref` |
| 3 | La aritmética antigua | A4 = V2 = P5 | El `<<` de `$[…]`, del desplazamiento de `${x:…}` y del índice de un array abre un heredoc que no existe, y una comilla de dos líneas esconde el comando siguiente | Saltar `$[…]`, `${…}` y `a[…]=` como `$((…))` |
| 4 | `.git/worktrees` | A5 = V5 | La carpeta que contiene los worktrees no está protegida: `chmod -R 000 .git/worktrees` pasa y `rm -rf` solo pide confirmación, aunque cada `.git/worktrees/<nombre>` sí lo está | `.git/worktrees` en `dir_re` |
| 5 | Falsos positivos | A3 = P2 | Un patrón de `grep` con alternativas (`'cp\|mv'`, `"chmod\|chown"`) o con un espacio delante del verbo sigue bloqueando la lectura de una carpeta protegida | Marcar el patrón entero, no solo la palabra que coincide con un verbo |
| 6 | Otros ejecutores | V1 = A7 | `tcsh -c`, `csh -c`, `env -S`, `trap '…' EXIT`, `su -c`, `script -c`, `flock -c` y un alias `!` de `git -c` ejecutan texto que el guard no lee | Más shells en `role()`; `env -S`, `trap` y `alias.*=!` como código; o nombrarlos en la fila «Regex evadibles» |
| 7 | Banco y caja | A8, A6 | Tres mutantes del destino de `cp`/`mv` sobreviven: `sc-30` no comprueba la búsqueda hacia atrás del último operando que es carpeta, el valor pegado (`--x=v`) ni la lectura con los argumentos de opción. Con un disco sin caja, la configuración de git de la persona escrita con otra caja solo se reconoce si `HOME` cuelga de `/Users`, `/home` o `/root` | Tres casos en `sc-30`; comparar `PERSONAL` sin caja |

## Disposición (gate **Resolución** 👤)

Decidida por una persona el 2026-11-03: una **ronda 4 mínima**, en una PR desde `main` (slices
R13 y R14 de `tasks.md`).

- **Se arregla en este cambio**:
  - los dos graves, P1 y V4, con el mismo arreglo en el cuerpo de un heredoc;
  - A1, `-n` detrás de una palabra que acaba en `;`, `&` o `|`;
  - A8, los tres casos que faltan en `sc-30`.
- **Deuda** en `STATUS.md`: A2 = V3 = P3, P4, A4 = V2 = P5, A5 = V5, A3 = P2, V1 = A7 y A6.
- Después se archiva, sin otro panel.
