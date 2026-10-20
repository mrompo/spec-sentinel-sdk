# Guía de uso — Spec Sentinel SDK

> Explicado en simple: qué puede hacer el framework hoy y cómo usarlo, paso a paso.
> **Esta guía crece con cada fase**: cuando una fase se archiva, su sección deja de decir
> "en construcción" y explica lo que ya puedes usar.

## ¿Qué es esto?

Un framework para desarrollar con agentes de IA sin cruzar los dedos: las reglas importantes
no se le *piden* al agente — se hacen **imposibles de saltar**. Se apoya en
[OpenSpec](https://github.com/Fission-AI/OpenSpec): primero se escribe qué debe hacer el
sistema (la *spec*), y el código se valida contra ella.

Un cambio recorre un **Loop** de tres stages, con **Shield** vigilando todo el rato
(vocabulario completo en [la semántica](05-semantica.md)):

| Stage | Para qué |
|---|---|
| **Engine** | Producir: entender qué se pide, afinarlo hasta que sea verificable, implementarlo |
| **Tribunal** | Juzgar: evaluación independiente de lo hecho |
| **Delivery** | Entregar y medir: a producción con rastro |

Y **Shield**, transversal, vigila todo el rato: no es un stage.

Dentro de cada stage hay **steps**, y para salir de cada step hay que cruzar un **gate**.

## ¿Qué puede hacer hoy?

| Capacidad | Estado | Cómo se usa |
|---|---|---|
| Desarrollar con el método SDD (cambios OpenSpec) | ✅ | Sección «El ciclo de trabajo» |
| Saber en qué punto está el proyecto | ✅ | Abre [`STATUS.md`](../STATUS.md) |
| Verificar la salud del framework | ✅ | Sección «Verificar que todo está bien» |
| Shield: reglas que el agente no puede saltarse | ✅ | Sección «Shield» |
| Abrir PRs con un formato que se revisa bien | ✅ | Paso 4 de «El ciclo de trabajo» |
| Instalarlo en tu propio proyecto (nivel Guardia) | ✅ fase 2 | Sección «Instalar en tu proyecto» |
| Gate de PR en CI + spec-coverage | 🔜 fase 3 | — |
| Skills del ciclo completo + doctor | 🔜 fase 4 | — |
| Release por entornos + carril hotfix | 🔜 fase 5 | — |
| Equipo de subagentes | 🔜 fase 6 | — |

## El ciclo de trabajo (cómo se hace un cambio)

Todo cambio —de código o del propio framework— sigue el mismo camino:

**1. Ábrelo.** Nada se toca sin su cambio OpenSpec:

```bash
git checkout -b feature/<nombre>
mkdir -p openspec/changes/<nombre>/specs/<capability>
```

Escribe 3 ficheros dentro:
- `proposal.md` — por qué y qué cambia (cabeceras `## Why` y `## What Changes`).
- `tasks.md` — la lista de pasos pequeños (checklist).
- `specs/<capability>/spec.md` — los escenarios: qué debe pasar y qué debe fallar,
  cada uno con su id (`SC-<capability>-01`, `SC-...-02`…).

**2. Valídalo y espera el visto bueno** (design gate — un humano revisa antes de implementar):

```bash
openspec validate --all --strict
```

**3. Implementa por pasos pequeños.** Para cada tarea del checklist: primero el test (en
rojo), luego el código mínimo que lo pone en verde, y un commit:

```bash
bash fixture/verify.sh        # rojo → implementas → verde
git add -A && git commit -m "feat(<área>): <qué>"
```

En zsh, si el mensaje lleva `!` (cambio incompatible, p. ej. `feat(api)!: …`), ponlo entre
comillas simples: con dobles, zsh lo toma por una referencia al historial y falla.

Marca la tarea con `- [x]` en el `tasks.md`. El progreso real vive ahí.

**4. Pide revisión y mergea.** Abre una PR con el formato del framework: título en
Conventional Commits y las diez secciones de
[`.github/pull_request_template.md`](../.github/pull_request_template.md) (Expediente,
Posición en el Loop, Qué cambia, Escenarios, Qué NO cambia, Verificación, Riesgos, Excepciones,
Procedencia y Foco de la revisión). Si una sección no aplica, se deja con `N/A — motivo`:
**nunca se borra**.

```bash
gh pr create --title "tipo(ámbito): descripción" --body-file pr.md   # pr.md parte de la plantilla
```

Desde la web, GitHub precarga la plantilla sola. **El merge lo hace una persona**: la
aprobación humana es la mitad del gate Aduana, y el agente tiene bloqueadas las ramas
protegidas (es la regla funcionando, no un fallo). Sin remote, el merge se hace en local:

```bash
git checkout main && git merge --no-ff feature/<nombre>
```

Si mergeas en GitHub, tu `main` local **no se actualiza solo**: tráelo con
`git fetch origin main:main` (o `git pull` estando en `main`).

**5. Archívalo.** Al terminar, la spec del cambio pasa a ser contrato vigente:

```bash
openspec archive <nombre> --yes
```

Y actualiza `STATUS.md` (posición nueva). Regla de oro: **si no sabes dónde estás,
`STATUS.md`; si no sabes qué hay activo, `openspec list`.**

## Verificar que todo está bien

```bash
bash fixture/verify.sh            # el framework se comprueba a sí mismo
openspec validate --all --strict  # las specs y cambios están bien formados
```

Si ambos están en verde, el repo está sano. Esto mismo corre en CI en cada PR
(cuando el repo tenga remote).

## Instalar en tu proyecto

Un comando instala el **nivel Guardia** (el Centinela y la Esclusa) en cualquier repo git, use o
no OpenSpec. Necesita `jq` (sin él no instala nada y te dice cómo instalarlo) y, para la
Esclusa, gitleaks. Desde la **raíz** de tu repo y en una rama, nunca en una protegida:

```bash
git checkout -b chore/spec-sentinel
bash <ruta-al-sdk>/ai-specs/skills/setup/setup.sh .
```

Si prefieres que lo haga el agente, expón la skill para Claude Code con este nombre (el
Centinela protege el instalador por esa ruta) y dale la ruta del SDK:

```bash
mkdir -p ~/.claude/skills
ln -sfn "$(cd <ruta-al-sdk> && pwd)/ai-specs/skills/setup" ~/.claude/skills/spec-sentinel-setup
ls ~/.claude/skills/spec-sentinel-setup/SKILL.md     # comprobación: el enlace llega al SDK
```

(El `$(cd … && pwd)` deja la ruta absoluta: un enlace con una ruta relativa se resolvería desde
`~/.claude/skills` y quedaría roto sin avisar.)

Ejecutará `setup` y te explicará la salida. Instalar reescribe el enforcement y lo decides tú: en
la primera instalación aún no hay Centinela, así que decides al pedírselo o al aprobar el
comando; al reinstalar o actualizar, el Centinela te pide aprobación antes de ejecutarlo.

**Windows**: el SDK y `setup` son bash. Con Git Bash o WSL funcionan, y el `.gitattributes` del
SDK (y el que `setup` deja en tu repo) mantiene en LF lo que ejecuta bash aunque Git for
Windows convierta a CRLF. En Git Bash, `ln -s` copia la carpeta en vez de enlazarla: crea el
enlace con `MSYS=winsymlinks:nativestrict ln -sfn …` (necesita el modo desarrollador) o, desde
Git Bash, con `cmd //c mklink /J` y rutas de Windows
(`cmd //c mklink /J "%USERPROFILE%\.claude\skills\spec-sentinel-setup" "<ruta-al-sdk>\ai-specs\skills\setup"`),
y compruébalo con `test -L ~/.claude/skills/spec-sentinel-setup`. Windows nativo no está
soportado de forma oficial.

**El `PATH`**: `setup` no ejecuta nada que venga del repo y quita de su `PATH` las carpetas del
repo (las que añaden direnv o `npm run`), diciéndolo. Abre Claude Code sin esas carpetas en el
`PATH`: el Centinela se ejecuta con el `bash` que encuentre ahí. Y no instales en tu carpeta
personal aunque sea un repo (dotfiles): `setup` lo rechaza, porque su `.claude/` es tu
configuración de usuario.

| Qué hace | Qué deja en tu repo |
|---|---|
| Copia el enforcement | `sentinel/`: hooks, git hooks, adaptadores y la política del SDK (`policy.default.yaml`) |
| Crea tu política | `sentinel/policy.yaml`, vacía, para tus reglas (con `sdd: true` si el repo tiene `openspec/`: el `pre-push` exigirá `openspec validate --strict`, y `setup` te avisa si ya falla) |
| Cablea el Centinela | `.claude/settings.json`: lo fusiona con lo tuyo usando `jq`, con backup, y comprueba que el cableado sea efectivo |
| Protege lo personal | Añade `.claude/settings.local.json` a tu `.gitignore`, junto a la llave y los backups, y comprueba con git que de verdad queden fuera |
| Fija los finales de línea | Añade `sentinel/** text eol=lf` a tu `.gitattributes` |
| Activa la Esclusa | `core.hooksPath` → `sentinel/githooks`, si tu repo no usa ya otros git hooks |
| Propone el stack | `sentinel/adapters/stack.proposed.yaml`, si reconoce Node o Laravel |
| Comprueba gitleaks | Te avisa ahora, no en el primer commit |

**Cómo termina**:

| Salida | Significa | Qué haces |
|---|---|---|
| `0` | Instalado | Commitea (abajo) |
| `3` | Instalado con pasos pendientes (líneas `⚠ PENDIENTE`) | Resuélvelos y vuelve a ejecutar `setup` hasta que salga `0` |
| `1` | Error (p. ej. falta `jq`: no se ha instalado nada) | Lee el motivo y corrígelo. Si falló a mitad, lo hecho se queda y volver a ejecutar `setup` es seguro |

**Los pendientes habituales** (cuando los resuelves, `setup` lo reconoce y sale con `0`):

- **gitleaks no está instalado** → instálalo (tabla en «Requisitos de la Esclusa», más abajo).
- **Ya usas otros git hooks** (husky, `.git/hooks`, un `core.hooksPath` propio o global) →
  `setup` no los toca: te da unas líneas para el principio de tus `commit-msg`, `pre-commit` y
  `pre-push` (con husky, en `.husky/<hook>`). Funcionan aunque tu hook lea las refs del push,
  como git-lfs, y no hacen nada en los repos que no tienen la Esclusa. Si ese `core.hooksPath`
  no tiene hooks en tu repo (por ejemplo, uno global cuya carpeta no existe ahí), no hay nada
  que encadenar: te da el comando que activa la Esclusa, que solo afecta a ese repo.
- **Tu `.claude/settings.json` no es JSON válido** (una coma de más o de menos, un comentario,
  un `NaN`, un número como `01`…) → Claude Code no carga el fichero entero, tampoco el
  Centinela. `setup` no lo toca y te dice dónde falla: corrígelo.
- **La forma de `hooks` en tu `.claude/settings.json` es inesperada** (un evento que no es una
  lista de grupos, o un grupo sin su lista `hooks`) → `setup` no fusiona sobre ella y te dice qué
  evento es: corrígelo y vuelve a ejecutar `setup`, que entonces añade el cableado.
- **`.claude/settings.local.json` ya está versionado**, o una regla posterior de tu `.gitignore`
  lo vuelve a incluir → sus cambios personales irían en tus commits. Sácalo del índice con el
  `git rm --cached` que te da `setup`, o quita esa regla.
- **Tu repo tiene `openspec/` y `openspec validate --all --strict` ya falla** → con `sdd: true`
  el `pre-push` lo exigirá y rechazaría el push. Corrige los cambios o, si el repo no quiere el
  nivel Método, pon `sdd: false` en `sentinel/policy.yaml`.
- **Tu `.gitignore` deja fuera algo que hay que versionar** (la plantilla de Node ignora
  `*.log`; hay repos que ignoran `.claude/`) → te dice qué fichero, qué regla lo ignora y la
  excepción que hay que añadir, y dónde: si la regla está en el `.gitignore` de una subcarpeta,
  la excepción va en ese.
- **Hay una llave sin usar** (`sentinel/.override`) → el Centinela dejaría pasar la primera
  acción que bloquee. Si no la pusiste tú para algo concreto, bórrala.
- **El Centinela lo deniega todo** → tu `sentinel/policy.yaml` tiene un error; `setup` te
  muestra el motivo.
- **Tu repo tiene `core.fileMode=false`** (habitual en Git for Windows y en WSL sobre `/mnt/c`)
  → git no guarda el permiso de ejecución y, en los clones, ignoraría los hooks. Tras el
  `git add`, marca los ejecutables con el `git add --chmod=+x …` que te da `setup`.
- **Hay un `disableAllHooks` que no es `false`** en `.claude/settings.json`, en
  `.claude/settings.local.json` o en tu configuración de usuario (`~/.claude/settings.json`) →
  Claude Code no ejecuta ningún hook, tampoco el Centinela (con un valor que no es booleano,
  puede no cargar el fichero entero). Quítalo o ponlo a `false`.
- **Hay un `env` que llega al Centinela o a git** en alguno de esos ficheros: variables
  `SENTINEL_*`, las que cambian cómo arranca bash o qué ejecuta (`BASH_ENV`, `SHELLOPTS`,
  `BASHOPTS`, `BASH_FUNC_*`, `LD_PRELOAD`, `LD_LIBRARY_PATH`, `DYLD_*`), las de la
  configuración de git (`GIT_CONFIG_*`, `GIT_DIR`, `GIT_WORK_TREE`, `GIT_EXEC_PATH`),
  `CLAUDE_PROJECT_DIR` o un `PATH` con entradas relativas o dentro del repo → Claude Code se las
  pasa al proceso del Centinela y a git, que cambiarían de política, de llave o de código, o
  dejarían sin efecto la Esclusa. Quítalas.
- **La configuración gestionada de tu organización** (`managed-settings.json`) tiene
  `allowManagedHooksOnly: true` o un `disableAllHooks` que no es `false` → Claude Code no
  ejecuta los hooks del proyecto. Lo resuelve quien administra esa configuración.

El **stack propuesto** no es un pendiente: revisa `stack.proposed.yaml` y, si te vale,
renómbralo a `stack.yaml`. Sin adaptador, la Esclusa omite format, lint y tests con un aviso.

**Al terminar**, versiona la instalación. Revisa lo que entra antes del commit, que ya pasa por
la Esclusa:

```bash
git add sentinel .claude .gitignore .gitattributes
git status                              # revisa lo que entra: nada personal de .claude/
git commit -m "chore: instala spec-sentinel (nivel Guardia)"
git commit --allow-empty -m prueba      # comprobación: la Esclusa tiene que rechazarlo
```

Y reinicia la sesión del agente para que cargue el Centinela (ver «Importante al instalar»).
Ábrela **en la raíz del repo**: en un subdirectorio (un paquete de un monorepo), Claude Code no
carga el `.claude/settings.json` de la raíz. Comprueba con `/hooks` que aparece
`sentinel-guard`: Claude Code descarta entero un settings que no valida su esquema, y `setup` no
lo comprueba todo.

**Cada persona que clone el repo** tiene que activar la Esclusa en su clon: `core.hooksPath`
es configuración local y no viaja con git. Basta con `git config core.hooksPath
sentinel/githooks` (o con ejecutar `setup`). El Centinela sí llega con el repo y, al arrancar la
sesión, avisa si la Esclusa no está activa en ese clon.

**Límite conocido: otros gestores de git hooks.** Con husky, lefthook, el framework pre-commit
o git-lfs, la Esclusa se encadena a mano en sus hooks y esas herramientas tienen su propio ciclo
de vida: lefthook y pre-commit regeneran sus hooks (y se pierden las líneas), husky instala los
hooks también en CI (en los jobs que commitean o publican, como una release, exporta `HUSKY=0`,
que también apaga la Esclusa ahí) y, si tu repo tiene hooks de git-lfs en `.git/hooks`, no
actives `core.hooksPath` a mano: ejecuta `setup`, que te da las líneas de encadenado. Resolverlo
bien va en su propio cambio,
[`hook-coexistence`](../openspec/changes/hook-coexistence/proposal.md).

**Para actualizar**, vuelve a ejecutar `setup`. Actualiza lo que es del SDK, también el
cableado de `.claude/settings.json` (si lo habías tocado, guarda tu versión en
`sentinel/.backup/`), y nunca toca lo tuyo: `policy.yaml`, `stack.yaml` ni la bitácora.

## Shield · las reglas estrictas

Las reglas viven en **la política**, que tiene dos ficheros:
[`sentinel/policy.default.yaml`](../sentinel/policy.default.yaml), con las del SDK (las
actualiza `setup`), y [`sentinel/policy.yaml`](../sentinel/policy.yaml), con las de tu
proyecto. Se aplican en el puesto del **Centinela** (el hook que intercepta cada acción del
agente); la **Esclusa** (git hooks) revisa cada commit y cada push, y la **Aduana** (CI) llega
en la fase 3. Cada regla vigila una acción y decide en uno de tres modos:

| Modo | Qué pasa |
|---|---|
| `block` | El agente no puede: la acción se deniega con el motivo explicado |
| `confirm` | No se ejecuta sin aprobación humana explícita |
| `warn` | Pasa, pero deja un aviso visible |

**Reglas activas hoy**: no commitear en ramas protegidas (`main`, `master`, `development`,
`preproduction`, `production`) · no force-push · no editar CHANGELOG, lockfiles ni specs
archivadas · no meter `.skip()`/`.only()` en tests · aviso al tocar config de cobertura ·
aviso al editar `src/` sin cambio activo (solo en el nivel Método) · `rm -rf`/`DROP`/`reset --hard` piden
confirmación · ejecutar o tocar el instalador desde la shell pide confirmación (y con las
herramientas de edición no se puede) · nada de `.env` de producción.

**Las ramas protegidas las fija el SDK**: tu proyecto no puede cambiar esa lista. Si trabajas
con `develop` o `staging`, de momento no quedan protegidas; ampliarla irá en un cambio aparte.

**Cómo añadir una regla**: en tu proyecto, añádela a `sentinel/policy.yaml` (id único + qué
vigila + `mode` + `reason`). Si una acción toca una regla del SDK y una tuya, gana la más
estricta (`block` antes que `confirm`, `confirm` antes que `warn`): puedes añadir protección, no
quitarla, y repetir un id del SDK es un error de política. Las dos políticas son ficheros
protegidos: las cambia una persona, no el agente. En el SDK, las reglas van en
`policy.default.yaml` y cada una lleva su caso en `fixture/hooks/cases/`. Sin test, la regla
no entra.

**Si un bloqueo te frena** (vía de emergencia auditada). Escribe el motivo en un fichero
**desde tu terminal**. La llave la crea siempre una persona: el Centinela impide que el agente
la escriba (SC-git-gates-14).


```bash
echo "hotfix INC-123 aprobado por tech lead" > sentinel/.override
```

El siguiente bloqueo se permite, se consume el token (**un solo uso**) y queda la línea en
`sentinel/overrides.log` con fecha, regla, acción y motivo. Si el registro no se puede
escribir, la excepción **se deniega**: sin auditoría no hay excepción.

Para toda una sesión (úsalo con cuidado, afecta a todas las reglas):
`SENTINEL_OVERRIDE="motivo" claude` al arrancar.

**La misma llave vale para la Esclusa** (los git hooks): si un commit o un push se rechaza,
la llave permite **ese** rechazo y lo registra en la bitácora como `esclusa:<hook>`. Si el
mismo commit lo rechazan dos hooks (p. ej. `pre-commit` y luego `commit-msg`), hacen falta dos
llaves: cada una cubre un solo rechazo. **No uses `git commit --no-verify`**: salta la Esclusa
sin dejar rastro, y la Aduana (fase 3) lo detectará igual.

Los modos `confirm` no necesitan override: el propio Claude Code te pide la aprobación de
**esa** acción concreta.

> **Importante al instalar**: los hooks se cargan **al arrancar la sesión** del agente. Si
> acabas de instalarlos (o de cambiar `.claude/settings.json`), reinicia la sesión: hasta
> entonces las reglas no se aplican, aunque los ficheros ya estén ahí.

**Qué más hacen los hooks**: al arrancar sesión el agente recibe la rama y el cambio activo
sin pedirlo; tras cada edición, el fichero se autoformatea si tu proyecto declara un comando
`format` en su adaptador de stack (si no, no pasa nada).

### Requisitos de la Esclusa: gitleaks es obligatorio

La Esclusa (los git hooks, fase 2) necesita **[gitleaks](https://github.com/gitleaks/gitleaks)**
para detectar secretos antes de cada commit. **No es opcional**: sin gitleaks, el `pre-commit`
rechaza el commit y muestra cómo instalarlo. Un secreto que llega a la historia de git es caro
de sacar, y cuesta menos exigir la herramienta que confiar en que cada máquina la tenga.

| Sistema | Instalación |
|---|---|
| macOS | `brew install gitleaks` |
| Linux | Binario de [releases](https://github.com/gitleaks/gitleaks/releases), o `go install github.com/zricethezav/gitleaks/v8@latest` |
| Windows | `scoop install gitleaks` |

Comprueba que está: `gitleaks version`. Vale cualquier v8: la Esclusa usa
`gitleaks git --pre-commit --staged` en v8.19 o posterior, y `gitleaks protect --staged` en las
anteriores.

Por debajo de gitleaks corre siempre una base de patrones en bash (claves de AWS, claves
privadas, tokens de GitHub y Slack), como segunda red. El resto de herramientas del
[adaptador de stack](../sentinel/adapters/README.md) sí son opcionales: si falta una, se omite
con aviso. Detalle en [`sentinel/githooks/README.md`](../sentinel/githooks/README.md).

## Glosario mínimo

Vocabulario completo y razonado en **[docs/05-semantica.md](05-semantica.md)**. Lo esencial:

- **Loop · Stage · Step · Gate** — el recorrido, sus etapas, lo que pasa dentro y la condición
  para salir.
- **Engine · Tribunal · Delivery** — los tres stages: producir · juzgar · entregar.
  **Shield** es transversal: no es una etapa, está siempre encendido.
- **Canon · Centinela · Esclusa · Aduana** — los cuatro puestos donde Shield se aplica:
  la intención, la acción, el registro y la integración.
- **Afinado (`tune`)** — nada se acierta a la primera: la spec, las reglas y los umbrales se
  ajustan con el uso.
- **Spec** — el contrato: qué debe hacer el sistema, en escenarios verificables.
- **Expediente** — un cambio en curso en `openspec/changes/` (proposal + tasks + delta).
- **Archivar** — cerrar un expediente: su spec pasa a ser contrato vigente.
- **El banco** — el banco de pruebas del propio framework (`fixture/`).
- **La llave / la bitácora** — la vía de emergencia auditada y su registro.
- **Niveles**: Guardia (solo Shield) · Método (+ Engine) · Equipo (+ Tribunal).
