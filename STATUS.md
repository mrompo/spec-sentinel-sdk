# STATUS — ¿En qué punto está el framework?

> Foto del estado, en dos niveles: **roadmap** (qué fase del SDK construimos) y **ciclo**
> (en qué fase §7 está el cambio activo). Se actualiza al abrir y al archivar cada cambio.
> Desde la fase 4, `doctor --status` generará este fichero; hasta entonces, se mantiene a mano.

**Última actualización**: 2026-11-08 · **`sentinel-paths` archivado**: nueve PRs en `main` (#9 a #13, #15 a #18, #20 a #22 y #24) en cuatro rondas de `apply`, tras tres paneles (`HOLD`, `HOLD` y `CONDITIONAL`); sus deltas pasan a las specs vivas `sentinel-guard` y `git-gates`, y lo que queda, a deuda · ningún cambio en `apply` · **fase 2 `git-gates` archivada**: las tres PRs en `main` (#3, #4 y #5) y sus specs vivas (`git-gates`, `sdk-setup`, `sentinel-guard`) actualizadas · `spec-purposes` archivado (PR #7): las seis specs vivas declaran su propósito y el banco impide dejarlo en «TBD» · siguientes: los gates Intención de `hook-coexistence` y `sdk-version`, y la fase 3 · historia reescrita con los mensajes de commit en español (misma topología y contenido)

## Posición actual

| Nivel | Estado |
|---|---|
| **Roadmap** | Fases 0, 1 y **2** ✅ archivadas · `framework-semantics`, `pr-format`, `spec-purposes` y `sentinel-paths` ✅ en `main` (fuera de roadmap) · siguiente: fase 3 (`ci-gate`) |
| **Loop** | Ningún cambio en `apply`. Dos expedientes esperan el gate **Intención** 👤: [`hook-coexistence`](openspec/changes/hook-coexistence/proposal.md) y [`sdk-version`](openspec/changes/sdk-version/proposal.md). Las revisiones de `sentinel-paths` (tres paneles: [primero](openspec/changes/archive/2026-11-08-sentinel-paths/review/README.md), [de confirmación](openspec/changes/archive/2026-11-08-sentinel-paths/review-2/README.md) y [corto](openspec/changes/archive/2026-11-08-sentinel-paths/review-3/README.md)) y las de `git-gates` 3/3 (cinco `HOLD` y dos `CONDITIONAL`, en su [expediente](openspec/changes/archive/2026-10-20-git-gates/review/README.md)) quedan archivadas |
| **Niveles entregados** | **Guardia**, salvo la Aduana: Centinela y Esclusa activos en este repo e instalables en cualquiera con `setup`; la Aduana llega en la fase 3 |

## Roadmap

| Fase | Cambio | Nivel | Estado |
|---|---|---|---|
| 0 | `bootstrap-method` | — | ✅ Archivada (`2026-07-27`) — [change](openspec/changes/archive/2026-07-27-bootstrap-method/proposal.md) |
| 1 | `sentinel-guard` | 0 | ✅ Archivada (`2026-08-05`) — hook único + política + break-glass auditado; 15 casos en el fixture; endurecida tras panel adversarial |
| — | `framework-semantics` | — | ✅ Archivada (`2026-09-28`, en `main` por la PR #1) — vocabulario del framework en `docs/05-semantica.md`; 8 escenarios, verificados por el banco |
| — | `pr-format` | — | ✅ Archivada (`2026-09-29`, en `main` por la PR #2) — título en Conventional Commits + diez secciones fijas; la plantilla la verifica el banco. Adelanta la plantilla de la fase 5 |
| — | `spec-purposes` | — | ✅ Archivada (`2026-10-21`, en `main` por la PR #7) — [change](openspec/changes/archive/2026-10-21-spec-purposes/proposal.md) · el `Purpose` de las seis specs vivas y la regla de `sdk-method` que impide dejarlo en «TBD» (SC-sdk-method-05) |
| 2 | `git-gates` | 0 | ✅ Archivada (`2026-10-20`, en `main` por las PRs #3, #4 y #5) — [change](openspec/changes/archive/2026-10-20-git-gates/proposal.md) · la Esclusa (commit-msg, pre-commit, pre-push), los ficheros protegidos y `setup`, que instala el nivel Guardia en un comando; siete paneles adversariales en la 3/3 |
| — | `sentinel-paths` | 0 | ✅ Archivada (`2026-11-08`, en `main` por las PRs #9 a #13, #15 a #18, #20 a #22 y #24) — [change](openspec/changes/archive/2026-11-08-sentinel-paths/proposal.md) · el Centinela decide por la ruta física y lee el comando como bash: las carpetas del enforcement enteras, los enlaces, `.git` y la configuración de git, `core.hooksPath` sin nombrarlo, la Esclusa con otra grafía, el cableado con un entorno limpio y la llave para una sola acción; tres paneles adversariales |
| 3 | `ci-gate` + `spec-coverage` CLI | 0/1 | Pendiente |
| 4 | `sdd-cycle` | 1 | Pendiente |
| 5 | `release-hotfix` | 1 | Pendiente |
| 6 | `team` | 2 | Pendiente |
| 7 | `agent-run-audit` *(opcional)* | 2 | Pendiente |

## Contratos vigentes

- **Specs vivas** (seis): [`sdk-method`](openspec/specs/sdk-method/spec.md) (método y symlinks
  multi-copilot), [`sentinel-guard`](openspec/specs/sentinel-guard/spec.md) (el puesto
  Centinela), [`git-gates`](openspec/specs/git-gates/spec.md) (la Esclusa),
  [`sdk-setup`](openspec/specs/sdk-setup/spec.md) (el instalador),
  [`pr-format`](openspec/specs/pr-format/spec.md) (el formato de PR) y `framework-semantics`
  (abajo). Todo cambio de framework nace con su expediente.
- **Semántica**: [`framework-semantics`](openspec/specs/framework-semantics/spec.md) — el
  vocabulario de [docs/05-semantica.md](docs/05-semantica.md) es contrato
  (`SC-framework-semantics-01..08`).
- **La política**: [sentinel/policy.default.yaml](sentinel/policy.default.yaml) (la del SDK)
  + [sentinel/policy.yaml](sentinel/policy.yaml) (la de este repo, nivel Método) — **con
  enforcement real** desde la fase 1 a través del Centinela.

## Salud / infraestructura

| Check | Estado |
|---|---|
| `fixture/verify.sh` | ✅ verde — 31 casos del Centinela + 16 de la Esclusa + 18 de instalación (uno end-to-end sobre `demo-app`) + estructura + semántica + plantilla de PR. El banco de instalación necesita jq |
| `openspec validate --all --strict` | ✅ verde (6 specs vivas + los 2 expedientes activos) |
| CI (`.github/workflows/fixture.yml`) | ✅ activo (remote `mrompo/spec-sentinel-sdk`), matriz macOS + Linux |
| KPIs activos (docs/04) | `overrides break-glass` — `sentinel/overrides.log`: 15 excepciones, del 2026-10-17 al 2026-10-20. Catorce son llaves que una persona concedió para que el agente escribiera los ficheros protegidos de las rondas 3 a 8 de `git-gates`; una la gastó un agente revisor con un comando de solo lectura. Desde la PR 2/3 de `sentinel-paths`, leer no se bloquea y la llave solo la gasta la acción que nombra su `para:`. `sentinel-paths` no gastó ninguna: los ficheros protegidos los aplicó una persona desde su terminal, con parches |
| Enforcement real | **Centinela y Esclusa activos en este repo**. El Centinela (`.claude/settings.json`) impide al agente commitear en ramas protegidas, tocar ficheros gestionados, debilitar tests o desarmar el propio guard. La Esclusa (`core.hooksPath` → `sentinel/githooks`, desde el 2026-10-16) revisa cada commit y cada push. La Aduana llega en la fase 3 |

## Deudas / pendientes conscientes

- El artefacto de revisión del plan menciona aún `docs/02`/`docs/03` (la investigación se movió
  al repo hermano `../spec-sentinel-research/`); se corrige en la próxima republicación.
- **Lo que el Centinela no lee** (quinta revisión de `git-gates`, cerrada en
  [`sentinel-paths`](openspec/changes/archive/2026-11-08-sentinel-paths/proposal.md)). El
  Centinela decide por la ruta física y lee el comando como bash, también dentro de `"$(…)"`,
  `bash -c` y `eval`. Siguen como límite documentado en la fila «Regex evadibles» de
  `sentinel/README.md`:
  - las llaves (`{a,b}`) y el contenido de `$'…'`;
  - las rutas montadas con variables y un `cd` previo;
  - lo que llega a una shell por otra vía: un script, `source` o una tubería a `bash`.
- **La protección de ficheros choca con operaciones legítimas.** `managed-files` y
  `self-protection` impiden al agente rellenar el `Purpose` de una spec viva recién archivada,
  deshacer un `openspec archive` que aún no está commiteado (pasó en `pr-format`, lo deshizo
  una persona) e incluso escribir en un comando un texto que *menciona* esas rutas: un heredoc
  que las nombre junto a `rm` o `mv` (pasa a menudo; se rodea escribiendo el texto en un
  fichero). El mensaje de commit o de PR en `"$(cat <<'EOF' … EOF)"` ya no se bloquea desde la
  #24. Leer ya no se bloquea desde la PR 2/3 de `sentinel-paths`, salvo con `protect-agents-md`, la regla de este repo, que no lleva
  `skip_read_only`: un `grep --include=*.md` bloquea porque el comodín alcanza `CLAUDE.md`.
  Va en un expediente propio del Centinela.
- Renombrar el job de CI `verify` (colisión asumida en docs/05 §10).
- **Convivencia de la Esclusa con otros gestores de git hooks** (husky, lefthook, pre-commit,
  git-lfs): sacada de `git-gates` tras su segunda revisión; expediente propio,
  [`hook-coexistence`](openspec/changes/hook-coexistence/proposal.md), con el gate Intención
  pendiente.
- **Versión del SDK instalada** (P3-4 de la tercera revisión de `git-gates`): `setup` no la
  registra, y reinstalar desde una copia más vieja revierte el enforcement sin aviso. Expediente
  propio, [`sdk-version`](openspec/changes/sdk-version/proposal.md), con el gate Intención
  pendiente.
- **Deuda de la tercera revisión de `git-gates`** (decisión del 2026-10-17, detalle en
  [round3/](openspec/changes/archive/2026-10-20-git-gates/review/round3/README.md)):
  - el parser de la política no recorta los comentarios en línea y mezcla una regla que no
    empieza por `- id:` con la anterior (A3-3);
  - la prueba de humo de `setup` no cubre Write, Grep, Glob, MultiEdit ni NotebookEdit
    (A3-prev-A2-7);
  - `session-start` compara texto en rutas relativas de `core.hooksPath` (A3-6) y sus avisos
    dan por hecho que el repo es el SDK (`STATUS.md`, OpenSpec) (P3-8).
- **Deuda de la cuarta revisión de `git-gates`** (decisión del 2026-10-18, detalle en
  [round4/](openspec/changes/archive/2026-10-20-git-gates/review/round4/README.md)):
  - el instalador se protege por sus dos rutas (`ai-specs/skills/setup/` y el enlace
    `~/.claude/skills/spec-sentinel-setup/`): un enlace con otro nombre no está protegido
    (resto de P4-5);
  - `setup` no valida el esquema completo de Claude Code, solo `disableAllHooks` y `env`; el
    resto queda como límite documentado y se comprueba con `/hooks` (resto de V4-3);
  - la carpeta de la skill en el SDK se llama `setup` y la skill `spec-sentinel-setup`: la
    Agent Skills spec pide que coincidan, y renombrar la carpeta toca el instalador y sus
    reglas.
- **Deuda de la séptima revisión de `git-gates`** (decisión del 2026-10-19, detalle en
  [round7/](openspec/changes/archive/2026-10-20-git-gates/review/round7/README.md)):
  - `LD_LIBRARY_PATH`, `DYLD_*` o `GIT_CONFIG_GLOBAL` legítimos en el `env` de los settings dejan
    un pendiente permanente; falta una forma de que la persona lo confirme sin relajar el
    criterio (P7-2);
  - un `PATH` de Windows en `env` (con `;` y `\`) se lee como entradas relativas (P7-3);
  - un `.gitignore` anidado que ignora una carpeta del enforcement lleva a un bucle de exit 3,
    porque la excepción propuesta no reincluye la carpeta (A7-4);
  - el cableado dependía del `PATH` de la sesión (A7-2): resuelto en la PR 3/3 de
    `sentinel-paths`, que lo ejecuta con un entorno limpio y falla cerrado. Queda como límite
    la shell con que Claude Code lanza el hook (`SHELLOPTS=noexec`).
- **Deuda del primer panel de `sentinel-paths`** (decisión del 2026-10-28, detalle en
  [review/](openspec/changes/archive/2026-11-08-sentinel-paths/review/README.md)):
  - `protect-enforcement-dirs` decide sobre el comando entero: nombrar `.claude` o `sentinel` en
    un tramo y tener un `rm` o un `cp` en otro (`ls -la .claude && rm -f tmp.txt`), o copiar la
    carpeta hacia fuera (`cp -r .claude /tmp/bk`), se bloquea. Haría falta decidir por tramo y
    solo sobre las palabras que siguen al verbo (P7);
  - el coste por llamada crece con cada palabra con `/` que existe, por los subshells de
    `phys_path` y `canon` (un heredoc de 60 líneas pasaba de 0,36 s a 1 s antes de contar solo
    las rutas que existen): faltan una caché por carpeta y un caso de rendimiento (P9).
- **Deuda del panel de confirmación de `sentinel-paths`** (decisión del 2026-10-31, detalle en
  [review-2/](openspec/changes/archive/2026-11-08-sentinel-paths/review-2/README.md)):
  - `git restore sentinel`, `git checkout <rev> -- sentinel` y `git stash push -- sentinel`
    pasan: borran las líneas de la bitácora que aún no están en un commit y traen una versión
    antigua del enforcement. Bloquear `git restore .` sería un falso positivo enorme, así que
    la bitácora necesita otra salida (V5);
  - Write o Edit a `sentinel\policy.yaml`, con barras invertidas, pasa. Falta comprobar qué
    ruta manda Claude Code en Windows (P6);
  - el coste crece más que en P9:
    - con el tope de 512 rutas y la copia a carpetas, el peor caso por llamada va de 8 a 24 s;
    - el tope de 10000 entradas es por carpeta, no por comando (P2);
  - menores y retoques:
    - el `cwd` del payload no se decodifica (A6);
    - el README dice que un heredoc no cuenta para el tope, y cuenta si nombra rutas que
      existen (A7);
    - en «solo lee», un `>` entre comillas cuenta como redirección (A8);
    - en Alpine y como root, el banco no sale en verde: `sc-30` necesita perl, `sc-18` un
      `tar --null`, y `sc-28` falla como root (A10);
    - `too-many-paths` bloquea lecturas, y su motivo engaña (P3);
    - la llave en heredoc no cierra si se pega con sangría (P4);
    - los remedios del cableado hablan al agente, y fallan desde una subcarpeta (P5);
    - el motivo llega detrás de los 2,2 KB del cableado (P7);
    - `id -un` sin `2>/dev/null` escribe un error en cada llamada si el uid no tiene nombre
      (P8);
    - `sed -n`, `awk`, `rg` y `jq` no cuentan como lectura, y el motivo dice «modifica» (P9);
    - el cuerpo de un heredoc cuenta como comandos, lo que amplía P7 (P10). Desde la #24 no
      cuenta en el mensaje de un commit o de una PR en `"$(cat <<'EOF' … EOF)"`;
    - `~+` y `~-` no se expanden (V7);
    - con `SENTINEL_OVERRIDE`, más de 512 rutas tapan en la bitácora la regla que se saltó
      (V8);
    - la fila «Regex evadibles» no menciona `tar -x`, `git apply` ni `patch` (V10);
    - el patrón de un `case` cuenta como un comodín de ruta: `case "$s" in *x*|"") …` se
      bloquea con `protect-agents-md`, porque `*x*` casa con `codex.md` (visto en la #20; ya
      pasaba en `main`).
- **Deuda del panel corto de `sentinel-paths`** (decisión del 2026-11-03, detalle en
  [review-3/](openspec/changes/archive/2026-11-08-sentinel-paths/review-3/README.md)):
  - un prefijo cuya opción lleva argumento (`sudo -u root`, `env -u X`, `timeout -s KILL`,
    `stdbuf -o L`, `exec -a g`) o un alias en el propio comando (`git -c alias.ci=commit ci`)
    esconde el `git commit` al Centinela; el pre-push sigue parando el push (A2 = V3 = P3);
  - `git -C` a otro worktree decide con la rama de la sesión (P4);
  - el `<<` de `$[…]`, del desplazamiento de `${x:…}` y del índice de un array abre un heredoc
    que no existe, y una comilla de dos líneas esconde el comando siguiente (A4 = V2 = P5);
  - la carpeta `.git/worktrees` no está protegida, aunque cada `.git/worktrees/<nombre>` sí
    (A5 = V5);
  - un patrón de `grep` con alternativas (`'cp\|mv'`) o con un espacio delante del verbo
    bloquea la lectura de una carpeta protegida (A3 = P2);
  - `tcsh -c`, `csh -c`, `env -S`, `trap '…' EXIT`, `su -c`, `script -c`, `flock -c` y un
    alias `!` de `git -c` ejecutan texto que el guard no lee (V1 = A7);
  - en un disco sin caja, la configuración de git de la persona escrita con otra caja solo se
    reconoce si `HOME` cuelga de `/Users`, `/home` o `/root` (A6).
- **Deuda de las revisiones de CodeRabbit de `sentinel-paths`**:
  - un `rsync` que nombra `.git`, también como argumento de una opción
    (`rsync -a --exclude .git src/ dst/`), se bloquea. Solo bloquea de más y ya pasaba en
    `main`; quitar el argumento de `--exclude` de las dos lecturas del destino abriría un
    escape en `cp`, `mv`, `ln` e `install` de BSD (revisión de la #22);
  - con `cat <<'EOF' > /tmp/x.sh` dentro del mensaje de un commit, el cuerpo se escribe en un
    fichero sin contar, y `bash /tmp/x.sh` lo ejecuta después. Es una forma más de «un script
    queda fuera»: en `main` ya pasaba `echo 'mv sentinel/githooks /tmp/y' > /tmp/x.sh; bash
    /tmp/x.sh` (aviso de seguridad de la #24, decisión del 2026-11-08);
  - `\cat` sin redefinir hace que el mensaje vuelva a contar: solo bloquea de más (#24).
- **El SDK no declara su `stack.yaml`**: en este repo la Esclusa omite format, lint y tests
  con aviso. Con `tests: bash fixture/verify.sh`, el `pre-push` correría el banco antes de
  cada push.
- Convención aprendida en fase 0: proposals con cabeceras `## Why` / `## What Changes`.
