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
**Posición en el Loop**: `tune` y `breakdown` escritos el 2026-10-26; esperan los gates
Claridad y Plan.

## Engine · antes de teclear

- [x] 0. `propose`: expediente abierto el 2026-10-18 desde la disposición de la revisión
- [x] 0a. Gate **Intención** 👤 — aprobado el 2026-10-26 (proposal §Decisiones)
- [ ] 0b. `tune` → gate **Claridad** ⚙️👤: delta de `sentinel-guard` (SC-sentinel-paths-01..09 y
       el break-glass modificado) y de `git-gates` (SC-git-gates-11 con la llave atada);
       `openspec validate --strict` en verde. Las dos preguntas abiertas se cerraron con las
       decisiones 1 y 2. Falta el visto bueno de la persona
- [ ] 0c. `breakdown` → gate **Plan** 👤: las tres PRs de abajo

## Checklist (`apply` ↺ `verify`, por slice)

**Tres PRs**: **1/3 · Lo que se toca** = slices 1-3 · **2/3 · Sin falsos positivos y la llave**
= slices 4-6 · **3/3 · Cableado** = slices 7-10. Cada una deja el banco en verde y es mergeable
sola. Ese orden también protege: la 1/3 cierra huecos y no relaja nada; la 2/3 relaja la
lectura sobre una protección ya basada en la ruta física.

### PR 1/3 · Lo que se toca (SC-sentinel-paths-01, 02, 03, 07)

- [ ] 1. Casos en rojo en `fixture/hooks/cases/`: carpetas enteras (`mv`, `rm -r`, `git rm -r`,
       `ln`, `chmod -R` sobre `sentinel`, `sentinel/hooks`, `sentinel/githooks`, `.claude`,
       `.git/hooks`, y sus subcarpetas libres); enlaces de fichero y de carpeta hacia
       `sentinel/`, `.claude/` y la configuración de git; un repo bare con worktree
       (`.bare/config`); `core.hooksPath` sin nombrarlo (`--remove-section core`,
       `--rename-section core`, `include.path`, `includeIf.*.path`, `config --edit`);
       `CLAUDE_CONFIG_DIR` en otra ruta
- [ ] 2. 👤 Parche `sentinel-paths-1.patch`: en la política, la regla de carpetas y
       `no-hook-disabling` ampliada; en el guard, la ruta física (la carpeta padre que exista
       y los enlaces del fichero) entra en la superficie de rutas, junto a la configuración de
       git real (`git rev-parse --git-common-dir` y `--git-dir`) y `$CLAUDE_CONFIG_DIR`
- [ ] 3. Banco en verde y `openspec validate --all --strict`; `sentinel/README.md` («regex
       evadibles» suma `cd` dentro de la carpeta) y `STATUS.md`. `merge` (una persona)

### PR 2/3 · Sin falsos positivos y la llave (SC-sentinel-paths-04, 05, 08; SC-sentinel-guard-08, 09; SC-git-gates-11)

- [ ] 4. Casos en rojo: los parecidos (`docs/.gitconfig.example`, `.git/config.bak`,
       `dotfiles/.gitconfig`, y `~/.gitconfig` que enlaza a `dotfiles/.gitconfig`, que sí se
       bloquea); solo lectura (lo que pasa y lo que sigue bloqueado: redirección, `tee`,
       `$(`, `git -c`, `--output`, `isolation-env`); la llave atada (otra acción no la gasta,
       la coincidencia es exacta, sin `para:` no vale, el aviso da la llave lista para copiar).
       Los casos actuales de la llave, en el Centinela (`sc-08-09`) y en la Esclusa
       (`fixture/githooks/cases/`), pasan al formato con `para:`
- [ ] 5. 👤 Parche `sentinel-paths-2.patch`: anclajes de la configuración de git en la política
       y `skip_read_only: true` en `self-protection` y `managed-files`; en el guard, la lista
       cerrada de solo lectura, la llave con `para:` y el aviso con la llave lista para copiar;
       en `sentinel/githooks/lib/breakglass.sh`, la llave con `para: esclusa:<hook>`
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
