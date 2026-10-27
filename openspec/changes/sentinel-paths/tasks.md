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
**Posición en el Loop**: PR 1/3 en `main` (#9); la 1b en su PR; la 2/3 con el parche listo.

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
- [ ] 3a. 👤 Revisión de la PR #9 (CodeRabbit, dos hallazgos de seguridad, los dos reales).
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
       (`mv -- -a/../sentinel`, un enlace `-s` a `sentinel`). Va en su propia PR, la 1e
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
- [ ] 5. 👤 Parche `sentinel-paths-2.patch`: anclajes de la configuración de git en la política
       y `skip_read_only: true` en `self-protection` y `managed-files`; en el guard, la lista
       cerrada de solo lectura, la llave con `para:` y el aviso con la llave lista para copiar;
       en `sentinel/githooks/lib/breakglass.sh`, la llave con `para: esclusa:<hook>`.
       El parche está listo el 2026-10-27, sobre la 1/3 con la 1b. En un clon con el parche, el
       banco entero sale en verde (hooks 27/27, githooks 16/16, install 17/17) y los catorce
       mutantes (un mecanismo saboteado cada vez) rompen algún caso
- [ ] 6. Banco en verde; `docs/guia-uso.md` (cómo se escribe la llave, para el Centinela y la
       Esclusa) y `sentinel/README.md`; la deuda del falso positivo sale de `STATUS.md`. `merge`

### PR 3/3 · Cableado (SC-sentinel-paths-06, 09)

- [ ] 7. Casos en rojo: el comando del cableado, tal como queda en `.claude/settings.json`,
       ejecutado con un `bash` y un `grep` trampa del repo en el `PATH`, con `BASH_ENV` y con
       una función exportada; con el script del Centinela ausente, ilegible o terminando con
       un código que no es 0 ni 2. Los casos de `fixture/install/` que comprueban el
       cableado (SC-sdk-setup-09, 10, 14) pasan al comando nuevo, que se sigue reconociendo
       por la ruta del script
- [ ] 8. 👤 Parche `sentinel-paths-3.patch`: el comando nuevo en `.claude/settings.json` y en
       `sentinel/settings.fragment.json`, y en el instalador el cableado que escribe y
       reconoce. Comprobado en macOS y en la matriz Linux de CI
- [ ] 9. 👤 Reiniciar la sesión del agente y comprobar con `/hooks` que el cableado nuevo carga
- [ ] 10. Banco en verde; en `sentinel/README.md` salen los límites «hook ausente» y «PATH de la
        sesión»; `STATUS.md`. `merge`

### Cierre

- [ ] 11. `review` (Auditor · Adversary · Pragmatist, contexto limpio) sobre las tres PRs →
        `disposition` 👤 de los hallazgos
- [ ] 12. `archive`: los deltas pasan a `sentinel-guard` y `git-gates`; `STATUS.md` y la guía al
        día, y la deuda que quede, registrada
