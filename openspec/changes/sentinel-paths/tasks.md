# Tasks — sentinel-paths

**Objetivo**: que el Centinela proteja lo que se toca (carpetas, rutas físicas, la configuración
de git real) y no el texto con que se escribe, sin bloquear trabajo legítimo, y que la llave
autorice la acción que la persona tenía en mente.
**Origen**: V5-1, V5-2, A5-3, V5-4, P5-6 y V5-7 de la quinta revisión de `git-gates`, A7-2 de la
séptima (el cableado depende del `PATH` de la sesión), y la deuda del falso positivo de solo
lectura de `STATUS.md`.
**Ritmo**: un slice = caso del banco en rojo → parche mínimo → verde → commit atómico. Todo lo
que toca el enforcement es un fichero protegido: lo entrega el agente como parche en la raíz del
worktree, sin trackear, y una persona lo revisa, lo aplica con `git apply --index`, comprueba el
banco y hace el commit.
**Posición en el Loop**: las tres PRs en `main` (#9 a #13); el primer panel dio `HOLD` y la ronda
2 de `apply` va por la revisión de la PR 5 (las PRs 4 y 5 en `main` por la #15 y la #16).

## Engine · antes de teclear

- [x] 0. `propose`: expediente abierto el 2026-10-18 desde la disposición de la revisión
- [x] 0a. Gate **Intención** 👤 — aprobado el 2026-10-26 (proposal §Decisiones)
- [x] 0b. `tune` → gate **Claridad** ⚙️👤: delta de `sentinel-guard` (SC-sentinel-paths-01..09 y
       el break-glass modificado) y de `git-gates` (SC-git-gates-11 con la llave atada);
       `openspec validate --strict` en verde. Las dos preguntas abiertas se cerraron con las
       decisiones 1 y 2. Aprobado por la persona el 2026-10-26
- [x] 0c. `breakdown` → gate **Plan** 👤: las tres PRs de abajo, aprobadas el 2026-10-26

## Checklist (`apply` ↺ `verify`, por slice)

**Tres PRs**: **1/3 · Lo que se toca** = slices 1-3 · **2/3 · Sin falsos positivos y la llave**
= slices 4-6 · **3/3 · Cableado** = slices 7-10. Cada una deja el banco en verde y es mergeable
sola. Ese orden también protege: la 1/3 cierra huecos y no relaja nada; la 2/3 relaja la
lectura sobre una protección ya basada en la ruta física.

### PR 1/3 · Lo que se toca (SC-sentinel-paths-01, 02, 03, 07)

- [x] 1. Casos en rojo en `fixture/hooks/cases/` (`sc-21` a `sc-24`, `7cb181a`): carpetas enteras (`mv`, `rm -r`, `git rm -r`,
       `ln`, `chmod -R` sobre `sentinel`, `sentinel/hooks`, `sentinel/githooks`, `.claude`,
       `.git/hooks`, y sus subcarpetas libres); enlaces de fichero y de carpeta hacia
       `sentinel/`, `.claude/` y la configuración de git; un repo bare con worktree
       (`.bare/config`); `core.hooksPath` sin nombrarlo (`--remove-section core`,
       `--rename-section core`, `include.path`, `includeIf.*.path`, `config --edit`);
       `CLAUDE_CONFIG_DIR` en otra ruta
- [x] 2. 👤 Parche `sentinel-paths-1.patch` (aplicado por la persona, `28b9fa7`): en la política, la regla de carpetas y
       `no-hook-disabling` ampliada; en el guard, la ruta física (la carpeta padre que exista
       y los enlaces del fichero) entra en la superficie de rutas, junto a la configuración de
       git real (`git rev-parse --git-common-dir`; la de cada worktree y submódulo vive
       dentro) y `$CLAUDE_CONFIG_DIR`.
       Parche listo el 2026-10-26: la regla `protect-enforcement-dirs` con la clave nueva
       `dir_re` (la ruta física de cada ruta del comando, anclada). Con él, en un clon limpio,
       el banco entero sale en verde (hooks 24/24, githooks 16/16, install 17/17) y los nueve
       mutantes (un mecanismo saboteado cada vez) rompen algún caso. Sube el coste del guard de
       unos 0,44 s a unos 0,53 s por llamada con un comando de 15 rutas
- [x] 3. Banco en verde y `openspec validate --all --strict`; `sentinel/README.md` («regex
       evadibles» suma `cd` dentro de la carpeta) y `STATUS.md`
- [x] 3a. 👤 Revisión de la PR #9 (CodeRabbit, dos hallazgos de seguridad, los dos reales).
       Primero, con 64 rutas de relleno delante el guard dejaba de mirar, y `rm -rf … sentinel`
       pasaba. Segundo, una ruta entre comillas con espacios (`"a b/../sentinel"`) se partía en
       dos. Hay caso en rojo (`sc-21`, `d8de6cb`) y parche `sentinel-paths-1b.patch`: las
       palabras del comando se leen como las vería la shell (comillas y escapes, con un awk) y,
       si hay más de 128 rutas, el comando se deniega en vez de dejar de mirar. Las tres
       variantes pasaban con el guard aplicado y la 1b las bloquea. La 1b va en la PR #10, y su
       revisión encontró dos rondas más. Primera, una ruta con un salto de línea se partía:
       la 1c (`f098606`). Segunda, los escapes se deshacían mal (`\t` como espacio, `\r` como
       salto, `\u00XX` sin decodificar, la barra con salto de línea dentro de "…") y un comodín
       sin comillas (`rm -rf sentin*`) no se expandía: la 1d, decisión de la persona del
       2026-10-27 (comodines sí; llaves, `$'…'` y sustituciones, límite documentado). Nueve
       mutantes mueren contra `sc-21`. La #10 se mergeó con la 1d (`897e421`, 2026-10-27). La
       tercera ronda llegó después: una palabra que empieza por '-' no contaba como ruta
       (`mv -- -a/../sentinel`, un enlace `-s` a `sentinel`). Va en su propia PR, la 1e: la #11,
       mergeada el 2026-10-27 (`22b631a`), con un caso que aísla las opciones (una política que
       protege `-f`). Con ella la revisión de la 1/3 queda cerrada
- [x] 3b. `merge` de la PR 1/3 (una persona, PR #9, `e95d401`, 2026-10-27). Entró sin la 1b,
       que llegó después del último push: va en su propia PR, desde `main`

### PR 2/3 · Sin falsos positivos y la llave (SC-sentinel-paths-04, 05, 08; SC-sentinel-guard-08, 09; SC-git-gates-11)

- [x] 4. Casos en rojo (`sc-25` a `sc-27`, `0fed05b`): los parecidos (`docs/.gitconfig.example`, `.git/config.bak`,
       `dotfiles/.gitconfig`, y `~/.gitconfig` que enlaza a `dotfiles/.gitconfig`, que sí se
       bloquea); solo lectura (lo que pasa y lo que sigue bloqueado: redirección, `tee`,
       `$(`, `git -c`, `--output`, `isolation-env`); la llave atada (otra acción no la gasta,
       la coincidencia es exacta, sin `para:` no vale, el aviso da la llave lista para copiar).
       Los casos actuales de la llave, en el Centinela (`sc-08-09`) y en la Esclusa
       (`fixture/githooks/cases/`), pasan al formato con `para:`. `sc-08-09` no cambia: usa
       `SENTINEL_OVERRIDE`, que no se ata
- [x] 5. 👤 Parche `sentinel-paths-2.patch` (aplicado por la persona, `1120f94`): anclajes de la configuración de git en la política
       y `skip_read_only: true` en `self-protection` y `managed-files`; en el guard, la lista
       cerrada de solo lectura, la llave con `para:` y el aviso con la llave lista para copiar;
       en `sentinel/githooks/lib/breakglass.sh`, la llave con `para: esclusa:<hook>`.
       El parche se rehízo el 2026-10-27 sobre `main` con la 1/3 cerrada (la 1b a la 1e), con
       un arreglo más: la solo lectura mira el texto del JSON sin decodificar, así que un
       comando con un escape de barra y `u` no cuenta como lectura (un separador o una
       redirección escritos así no se verían; caso en rojo en `sc-26`). En un clon limpio con el
       parche, el banco entero sale en verde (hooks 27/27, githooks 16/16, install 17/17) y los
       quince mutantes (un mecanismo saboteado cada vez) rompen algún caso
- [x] 6. Banco en verde; `docs/guia-uso.md` (cómo se escribe la llave, para el Centinela y la
       Esclusa) y `sentinel/README.md`; la deuda del falso positivo sale de `STATUS.md`. `merge`
       (PR #12, `a19d685`, 2026-10-28). Su revisión encontró un `--output` entre comillas que
       pasaba por lectura (`eaec491`), y al rehacer el parche sobre `main` salió el de los
       escapes del JSON

### PR 3/3 · Cableado (SC-sentinel-paths-06, 09)

- [x] 7. Casos en rojo (`sc-28`, `456b252`): el comando del cableado, tal como queda en
       `.claude/settings.json`, ejecutado con `/bin/sh` y con un `bash`, `grep`, `sed`, `git` y
       `awk` trampa en el `PATH`, con `BASH_ENV`, `SHELLOPTS=noglob`, una función exportada y
       un `GIT_DIR` de otro repo; con el script del Centinela ausente, ilegible o terminando
       con un código que no es 0 ni 2. Con el cableado de `main`, cada amenaza rompe alguna
       comprobación. Los casos de `fixture/install/` no cambian: el instalador copia el
       cableado del SDK y lo reconoce por la ruta del script, y `sc-09` ejecuta el instalado.
       `SHELLOPTS=noexec` actúa sobre la shell que lanza el hook, antes del cableado: queda
       como límite en `sentinel/README.md`
- [x] 8. 👤 Parche `sentinel-paths-3.patch` (aplicado por la persona, `31020b5`): el comando
       nuevo en `.claude/settings.json` (`/usr/bin/env -i`, `PATH` fijo con NixOS, cuatro
       variables, fail-closed). `sentinel/settings.fragment.json` no se versiona: `setup` lo
       genera de ese mismo fichero. En el instalador cambia solo el aviso del `PATH`, que ya no
       es cierto. Comprobado en macOS (banco completo en un clon limpio); Linux, en la CI
- [x] 9. 👤 Reiniciar la sesión del agente y comprobar con `/hooks` que el cableado nuevo carga
       (la persona, 2026-10-28)
- [x] 10. Banco en verde; en `sentinel/README.md` salen los límites «hook ausente» y «PATH de la
        sesión»; `STATUS.md`. `merge` (PR #13, `cacbe86`, 2026-10-28). Banco en verde (hooks
        28/28, githooks 16/16, install 17/17), y en el README los dos límites dejan su sitio a
        «La shell que lanza el cableado». Su revisión pidió que el cableado bloquee sin git y
        que el hook lleve `"onFailure": "block"` (`9bd20df`)

### Cierre

- [ ] 11. `review` (Auditor · Adversary · Pragmatist, contexto limpio) sobre las tres PRs →
        `disposition` 👤 de los hallazgos. Primer panel el 2026-10-28
        ([`review/`](review/README.md)): `HOLD` por V1, con 8 graves y los 26 hallazgos
        validados. Disposición de la persona el mismo día: se arregla en este cambio (ronda 2,
        abajo) salvo P7 y P9, que van a deuda, y después un panel de confirmación

### Ronda 2 · arreglos de la revisión (disposición del 2026-10-28)

Mismo ritmo: caso en rojo → parche 👤 → verde. Tres PRs desde `main`, cada una mergeable sola.

**PR 4 · Lo que ejecuta bash** (temas 1 y 2 de la revisión)

- [x] R1. Casos en rojo (`sc-29` nuevo, y `sc-23` y `sc-26`): un salto de línea o un tabulador escritos como escape del JSON delante
       del verbo (V1); el verbo por su ruta, con barra o entre comillas (V2); `git config
       remove-section`/`rename-section`/`edit` sin guiones (A2); `core.hookspath` en otra caja,
       `include.PATH`, `--config-env` y `GIT_CONFIG_KEY_n` (A3 = V3); y en solo lectura, un `\|`
       entre comillas (P8 = V7), `2>/dev/null` junto a un separador (A5) y `printf -v` (V6)
- [x] R2. 👤 Parche `sentinel-paths-4.patch` (aplicado por la persona, `c37d293`): las reglas del comando deciden sobre el comando decodificado y el verbo de
       cada tramo sin comillas ni escapes y reducido a su nombre; los tramos de solo lectura se
       parten respetando las comillas; claves de git sin distinguir mayúsculas. En un clon
       limpio con el parche, el banco entero en verde (hooks 29/29, githooks 16/16, install
       17/17) y los trece mutantes rompen algún caso. Revisión de la #15 (CodeRabbit): las
       opciones antes de `core` en `remove-section`/`rename-section` (`1a9837b`), y los
       comentarios, `$'…'` y heredocs que escondían las líneas siguientes (`0b19eb6`, ocho
       mutantes muertos); las variables (`$K.$H`) quedan como límite documentado (decisión del
       2026-10-27). En `main` por la #15

**PR 5 · Carpetas y ruta física** (tema 3 y el tope de 128 rutas)

- [x] R3. Casos en rojo (`sc-30` nuevo, y `sc-22` y `sc-23`): copiar o mover a `.git`, `sentinel/adapters` o `sentinel/githooks/lib`
       (A1); worktrees dentro del repo bare (P2); la carpeta común de git con el `cwd` fuera del
       proyecto (A4) y el `cwd` del payload (V5); `enlace/../x` en Write/Edit (A7); un heredoc o
       un `git add` con más de 128 palabras con `/` que no tocan nada protegido (P5 = A8)
- [x] R4. 👤 Parche `sentinel-paths-5.patch` (aplicado por la persona, `f7323c9`): el `cwd` del
       tool call, la ruta tal cual y la física, la carpeta común de git desde el proyecto, gana
       el prefijo más largo, copiar o mover a una carpeta (también con `-t`), las carpetas
       `sentinel/githooks/lib`, `sentinel/adapters` y `.husky`, y el tope de 512 rutas (solo las
       que existen o cuya carpeta existe; se bloquea y la llave de esa acción lo salva). README
       («Regex evadibles») con el tope real. Sobre la PR 4 con su revisión, el banco entero en
       verde (hooks 30/30, githooks 16/16, install 17/17) y los doce mutantes rompen algún caso.
       En `main` por la #16. Revisión de la #16 (CodeRabbit), en `sentinel-paths-5b.patch`
       (aplicado por la persona, `6e12e2a`): copiar a una carpeta con el programa detrás de un
       prefijo o de una asignación, con los orígenes de un comodín, con el contenido de una
       carpeta (`rsync` con `/` al final, `-T`), con `-t` en un grupo de opciones y con lo que hay
       dentro de una carpeta copiada o enlazada (tope de 10000 entradas). Banco entero en verde y
       los doce mutantes rompen algún caso. `too-many-paths` sigue en el guard, no en la
       política: dice que el guard no pudo comprobar la acción entera (como SC-09), y el esquema
       no tiene campo para expresarla; la llave la salva. Revisión de la #17 (CodeRabbit), en
       `sentinel-paths-5c.patch` (aplicado por la persona, `db69e15`): una entrada que ya está en
       el destino como enlace toca lo que apunta, una carpeta que el guard no puede leer entera
       se bloquea con `too-many-paths`, y cada tope da su motivo. Banco entero en verde y los
       diecinueve mutantes (siete nuevos y los doce de la #16) rompen algún caso. Falta el `merge`

**PR 6 · El cableado en el uso real y la llave** (temas 4, 5 y 7)

- [ ] R5. Delta de SC-sentinel-paths-09 (sin git que responda en el proyecto, el cableado bloquea
       y dice por qué) y casos en rojo: `git` solo fuera del `PATH` fijo, y `setup` lo detecta
       (P1); rama sin el SDK (P3); *dubious ownership* (P6 = A9); la llave copiada del aviso, tal
       cual, en el Centinela y en la Esclusa (P4 = A6); `SENTINEL_OVERRIDE` con una llave para
       otra acción (V4)
- [ ] R6. 👤 Parche (cableado, `setup`, guard y `breakglass.sh`), banco en verde, `STATUS.md` y
       `sc-28` al día (A10), deuda P7 y P9 registrada, y `merge`

**Tribunal**

- [ ] R7. Panel de confirmación (tres lentes nuevas, contexto limpio) sobre las PRs 4 a 6 →
       `disposition` 👤
- [ ] R8. Lo que decida la persona; después, el 11 queda cerrado
- [ ] 12. `archive`: los deltas pasan a `sentinel-guard` y `git-gates`; `STATUS.md` y la guía al
        día, y la deuda que quede, registrada
