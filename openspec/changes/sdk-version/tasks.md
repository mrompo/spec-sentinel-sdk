# Tasks — sdk-version

**Objetivo**: saber qué versión del SDK está instalada en cada repo y que reinstalar desde una
copia más vieja o con cambios sin commitear no revierta el enforcement sin que la persona lo
decida.
**Origen**: P3-4 de la tercera revisión de `git-gates`.
**Ritmo**: un slice = caso del banco en rojo → parche mínimo → verde → commit atómico. Lo que
toca el enforcement (`setup.sh`, `session-start.sh`, `policy.default.yaml`) es un fichero
protegido: lo entrega el agente como parche en la raíz del worktree, sin trackear, y una persona
lo revisa, lo aplica con `git apply --index`, comprueba el banco y hace el commit.

## Engine · antes de teclear

- [x] 0. `propose`: expediente abierto el 2026-10-17 desde la disposición de la revisión
- [x] 0a. Gate **Intención** 👤 — aprobado el 2026-11-08 (proposal §Decisiones)
- [x] 0b. `tune` → gate **Claridad** ⚙️👤: delta de `sdk-setup` (SC-sdk-version-01..07) y de
       `sentinel-guard` (SC-sdk-version-08); `openspec validate --strict` en verde. Aprobado
       por la persona el 2026-11-08
- [x] 0c. `breakdown` → gate **Plan** 👤: las dos PRs de abajo y un panel antes del `archive`,
       aprobados el 2026-11-08

## Checklist (`apply` ↺ `verify`, por slice)

**Dos PRs**: **1/2 · La versión** = slices 1-3 · **2/2 · Activar** = slices 4-6. Cada una deja
el banco en verde y es mergeable sola.

### PR 1/2 · La versión

- [x] 1. Casos en rojo en `fixture/install/`: la primera instalación y una sin versión anterior
       (SC-01, SC-02), una copia más vieja, una de otra rama y una que no es un clon de git
       (SC-03), una con cambios sin commitear (SC-04) y `--downgrade` (SC-05). En
       `fixture/hooks/`, escribir y borrar `sentinel/.sdk-version`, y leerlo (SC-08)
       → `install/sc-19` y `hooks/sc-32` (`c6fef43`), que fallan con el `setup` y la política
         actuales; el resto del banco de instalación pasa. El harness de instalación ejecuta
         `setup` desde una copia limpia del SDK, porque `setup` ya no instala desde una con
         cambios sin commitear. `db43753` añade los casos que pedían cuatro mutantes
- [x] 2. 👤 Parche: `setup.sh` (el fichero de versión, la comparación por ascendencia y
       `--downgrade`) y `policy.default.yaml` (`sentinel/.sdk-version` en `self-protection`)
       → `58563b2`, aplicado y commiteado por la persona. `fixture/verify.sh` en verde en un clon
         (hooks 32, githooks 16, install 19); en Debian 12, el banco de instalación entero y
         `hooks/sc-13`, `sc-26` y `sc-32`; los 11 mutantes del arreglo hacen fallar algún caso
- [x] 3. La guía (instalar y actualizar) y `sentinel/README.md` → `19f573f`
- [x] 3a. Revisión de CodeRabbit en la #26: un `git status` que falla (un índice dañado) se leía
       como una copia limpia. Caso en `sc-19` (`78bb665`, en rojo con el `setup` anterior) y
       parche 👤 `ba8dd57`: si falla, la copia cuenta como con cambios y `setup` dice por qué.
       Banco completo en verde en un clon, Debian 12 en verde y 2 de 2 mutantes muertos. El
       aviso de «Docstring Coverage»: `short()` lleva su comentario, como el resto de funciones

### PR 2/2 · Activar

- [x] 4. Casos en rojo: `setup --activate` en un clon con la instalación versionada, con otros
       git hooks y con la instalación incompleta (SC-06); el aviso de `session-start` en ese
       clon (SC-07)
       → `install/sc-20` y `hooks/sc-33` (`94cb843`), que fallan con el `setup` y el
         `session-start` actuales (opción desconocida, el aviso de siempre)
- [x] 5. 👤 Parche: `setup.sh` (`--activate`) y `session-start.sh` (el aviso)
       → `2c820e2`, aplicado y commiteado por la persona. `fixture/verify.sh` en verde en un clon
         (hooks 33, githooks 16, install 20); en Debian 12, el banco de instalación entero y
         `hooks/sc-11`, `sc-13`, `sc-19`, `sc-26`, `sc-32` y `sc-33`; los 15 mutantes del arreglo
         hacen fallar algún caso (cinco sobrevivían a la primera versión de `sc-20`, que se
         reforzó)
- [x] 6. La guía (el clon de un compañero) y `sentinel/README.md` → `9478985`
- [x] 6a. Revisión de CodeRabbit en la #27: `--activate` no exigía `sentinel/adapters/stack.sh`,
       aceptaba enlaces simbólicos y git hooks ejecutables en el clon pero no en git, y el
       Centinela cableado en cualquier evento; su prueba de humo lanzaba el cableado de la copia
       del SDK, no el del clon. Casos en `sc-20` (`61fccd7`, en rojo con el `setup` anterior) y
       parche 👤 `cd8a696`. Banco completo en verde en un clon, Debian 12 en verde y 8 de 8
       mutantes muertos. Fuera: un comando del cableado que solo nombra el script (un `echo`) y
       los matchers; `--activate` confía en el cableado versionado, que ya pasó revisión

### Cierre

- [x] 7. `review` (Auditor · Adversary · Pragmatist, contexto limpio) sobre las dos PRs →
       `disposition` 👤 de los hallazgos. Panel del 2026-11-09 ([`review/`](review/README.md)):
       `CONDITIONAL`, con 19 de 20 hallazgos validados (4 graves: A1, P1, P2 y P3) y V4 sin
       validar. Disposición de la persona el mismo día: ronda 2 (abajo) con los graves y los
       menores baratos; V1, V3, V5 y V4, a deuda; después, un panel corto de confirmación
- [ ] 8. `archive`: los deltas pasan a `sdk-setup` y `sentinel-guard`; `STATUS.md` y la guía al
       día, y la deuda que quede, registrada

## Ronda 2 · arreglos del panel (disposición del 2026-11-09)

Mismo ritmo: caso en rojo → parche 👤 → verde, con mutantes. Dos PRs desde `main`, cada una
mergeable sola. A4 = V2 recoge lo que la revisión de CodeRabbit en la #27 dejó fuera (6a).

**PR 3 · La copia del SDK** (temas 1, 2 y 5 del panel, y P4)

- [x] R1. Casos en rojo en `fixture/install/sc-19` → `4461b96`:
       - una copia sin git en un repo sin `.sdk-version` → se niega; con `--downgrade`, instala
         y no registra `dirty=no` (A1);
       - tras instalar desde una copia sin git, `setup` desde un clon limpio y más nuevo →
         instala con aviso, sin `--downgrade` (P1 = V7);
       - un `.vscode/` sin versionar en la copia → instala; un fichero sin versionar en
         `sentinel/hooks` sigue rechazado, y el mensaje lo nombra (P2);
       - con `status.showUntrackedFiles=no`, o con un fichero ignorado en `sentinel/githooks` →
         se niega (A2);
       - `.sdk-version` como carpeta o como enlace simbólico → se niega y no escribe fuera del
         repo (A6 = V6);
       - una copia superficial más nueva → el mensaje propone `git fetch --unshallow` (P4).
       `sc-18`, que instala desde una copia sin git, se ajusta
- [x] R2. 👤 Parche: `setup.sh` → `1e0f411`. Banco completo en verde en un clon (hooks 33,
       githooks 16, install 20), Debian 12 en verde y 11 de 11 mutantes muertos
- [x] R3. La guía, `sentinel/README.md` y el delta de SC-02, 03 y 04 → `f213fab`
- [x] R3a. Revisiones de CodeRabbit en la #28. Primera → `400f97f`: SC-05 excluye el
       `.sdk-version` que es enlace o carpeta; la guía y `sentinel/README.md` dicen que, sin
       versión registrada, un clon limpio instala; `synthesis.sh` falla ante una severidad
       desconocida (el veredicto del panel no cambia). Segunda → la guía da los comandos sobre la
       copia del SDK (`git -C <ruta-al-sdk> pull`), y SC-03 rechaza un enlace (también roto) o
       una carpeta sin proponer `--downgrade` (`76093a6`); caso en `sc-19` (`4099fd1`, en rojo
       con el `setup` anterior) y parche 👤 `c4fa9e0`. Banco completo en verde salvo
       `hooks/sc-21` en un worktree (verde en un clon; no toca `sentinel/`), CI verde en macOS y
       Linux. La tercera revisión, sobre `c4fa9e0`, sin comentarios

**PR 4 · Activar** (temas 3, 4 y 6 del panel, salvo P4)

- [x] R4. Casos en rojo en `fixture/install/sc-20` y `fixture/hooks/sc-33` → `c269d58`:
       - un clon instalado antes de `sdk-version` → `--activate` activa con aviso, no
         «instálalo con setup»; solo un repo sin el SDK versionado manda a `setup` (P3);
       - el Centinela con el matcher `Read`, o con un comando que no lo ejecuta (`… || true`)
         → no activa; la prueba de humo comprueba también una acción que tiene que bloquearse,
         en `setup` y en `--activate` (A4 = V2);
       - el `.gitattributes` del clon sin su línea, y `post-edit.sh` y `session-start.sh`
         fuera de su evento (A5);
       - git hooks commiteados sin bit de ejecución → el mensaje da `git add --chmod=+x` (P5);
       - `core.fileMode=false` y una copia del SDK de otra versión → no pide marcar un fichero
         que el clon no tiene (A3);
       - el aviso de arranque dice qué hacer si la copia no conoce `--activate` (P6);
       - con una llave sin usar en el clon, la prueba de bloqueo no se hace y no la gasta
       `sc-18` comprueba que `setup` avisa de un cableado que deja pasar lo que tiene que bloquear
- [x] R5. 👤 Parche: `setup.sh` y `session-start.sh` → `ce4871b`. Banco completo en verde en un
       clon (hooks 33, githooks 16, install 20), Debian 12 en verde y 11 de 11 mutantes muertos
- [x] R6. `SKILL.md` (`--activate`, y que `--downgrade` lo decide la persona: P7), la guía,
       `sentinel/README.md` y el delta de SC-06 y 07 → `e5e3d40`

**Cierre de la ronda**

- [ ] R7. Panel corto de confirmación (tres lentes nuevas, contexto limpio) sobre las PRs 3 y
       4 → `disposition` 👤
