# Proposal — git-gates (fase 2 · el puesto Esclusa y el nivel Guardia instalable)

> Reabierta el 2026-09-28 tras `framework-semantics`: reescrita con el vocabulario de
> [docs/05-semantica.md](../../../docs/05-semantica.md). Sustituye a la versión aparcada del
> 2026-08-05; el alcance técnico se mantiene y se añaden los hallazgos de la semántica.

## Why

Shield tiene hoy **un solo puesto operativo**: el **Centinela**. Funciona, pero tiene dos
límites que ya hemos visto en la práctica:

1. **Evalúa texto, no resultados.** El panel adversarial de la fase 1 demostró que un TOCTOU de
   rama o una grafía de comando no prevista se le escapan (falsos negativos). Y al usarlo a
   diario hemos visto la otra cara: bloquea comandos de solo lectura que *nombran* un fichero
   protegido (falsos positivos, registrado en `STATUS.md`). Las dos cosas tienen la misma
   causa: juzga la intención escrita, no lo que ocurrió.
2. **Solo existe en este repo, y a mano.** Instalarlo en otro proyecto obliga a copiar ficheros
   y editar `.claude/settings.json` sin equivocarse. El nivel **Guardia** no es un producto
   hasta que se instala con un comando.

La **Esclusa** resuelve el primer límite porque actúa **sobre el resultado**: el commit existe
o no existe, y da igual si lo intentó un agente, una persona o un script. No hay ventana de
esquive. El **instalador** resuelve el segundo. Con los dos, el nivel Guardia pasa del 50% al
75%; la **Aduana** (fase 3) lo completa.

## What Changes

1. **El puesto Esclusa** — `sentinel/githooks/`, instalables vía `core.hooksPath`:
   - `commit-msg`: Conventional Commits en bash puro (sin Node), con bypass para merges y
     `chore(release)`.
   - `pre-commit`: detección de secretos (**gitleaks obligatorio**) + `format --check` + `lint` del
     adaptador, **solo sobre staged**.
   - `pre-push`: `tests` del adaptador + `openspec validate --strict` (nivel Método) + **la rama
     protegida se valida aquí de verdad** (cierra el TOCTOU del Centinela).
   - Patrón **skip-vs-fail**: herramienta ausente = skip con aviso visible; entorno roto = fallo
     duro con la instrucción exacta de arreglo. Nunca pasar en silencio.
2. **El adaptador de stack** — `sentinel/adapters/stack.yaml` (renombrado desde el ambiguo
   `sentinel.yaml`, hallazgo #27 del panel): declara `format · lint · static · tests ·
   env-ready`, con autodetección para Node y Laravel. Esclusa, Aduana y el Centinela (formateo
   tras editar) lo consumen sin conocer el stack.
3. **La instalación** — skill `setup`: un comando instala el nivel Guardia en cualquier repo:
   copia `sentinel/`, cablea el Centinela **fusionando** `.claude/settings.json` si ya existe
   (backup siempre; si la fusión no es segura, deja el fragmento y explica el paso manual),
   configura `core.hooksPath` y detecta el stack. Idempotente.
4. **Política distribuida vs política del consumidor** (hallazgo #20):
   `sentinel/policy.default.yaml` (viene con el SDK, se actualiza) y `sentinel/policy.yaml` (del
   consumidor, nunca se pisa). La bitácora (`overrides.log`) sale del paquete: es append-only y
   del consumidor.
5. **El banco** — casos de la Esclusa (cada hook, incluido skip-vs-fail) e **instalación real
   en `fixture/demo-app/`** con un solo comando, verificando que después bloquea.
6. **Semántica** — ajustar la definición del gate **Esclusa** en `docs/05-semantica.md` según
   se decida en la cuestión 1 de abajo.

## What does NOT change

- Las reglas del Centinela ni sus modos (`block`, `confirm`, `warn`). El falso positivo de la
  autoprotección **no** se arregla aquí: es del Centinela y va en su propio expediente.
- La Aduana (CI) sigue siendo la de hoy: el gate de PR completo llega en la fase 3.

## Impact

- Nuevos: `sentinel/githooks/{commit-msg,pre-commit,pre-push}`, `sentinel/adapters/stack.yaml`,
  `ai-specs/skills/setup/SKILL.md`, `fixture/githooks/*`, `fixture/install/*`.
- Modificados: la política se separa en `policy.default.yaml` + la local; `post-edit.sh` (nuevo
  nombre del fichero de stack); READMEs; `docs/guia-uso.md` (sección «Instalar en tu
  proyecto»); `docs/05-semantica.md` (gate Esclusa); `.gitignore`.
- Tras esta fase, **este repo usa su propia Esclusa**: los commits que no cumplan Conventional
  Commits dejan de entrar, para agentes y personas por igual.

## Riesgos

- **Slices que tocan el propio enforcement.** Renombrar el fichero de stack en `post-edit.sh`
  y separar la política modifican ficheros que el Centinela protege (`self-protection`). El
  agente **no puede** hacerlos solo, y es correcto que no pueda: esos slices los ejecuta una
  persona o se hacen con la llave (`sentinel/.override`), y quedan en la bitácora. Se agrupan
  en slices propios para que la excepción cubra lo mínimo.
- **Auto-instalación en este repo.** En cuanto `core.hooksPath` apunte a la Esclusa, un hook
  roto bloquea todos los commits. Se instala al final, con el banco en verde, y con el
  skip-vs-fail probado antes.

## Decisiones (gate Intención y `tune`, 2026-09-29)

| # | Cuestión | Decisión |
|---|---|---|
| 1 | ¿Dónde se cierra el gate Esclusa? | **En dos tiempos**: al commitear (mensaje, secretos, formato) y al publicar (tests, rama protegida). `docs/05` se ajusta para decirlo. Pasar los tests en cada commit es lento y empuja a saltárselos |
| 2 | ¿Un expediente o dos? | **Uno, con dos capabilities**: `git-gates` (la Esclusa) y `sdk-setup` (la instalación). El DoD de la fase es "nivel Guardia instalable con un comando", y cada capability acaba con su propia spec viva |
| 3 | Fusión de `.claude/settings.json` | **`jq` si existe**; si no, `sentinel/settings.fragment.json` con la instrucción manual. Nunca una fusión propia en bash (SC-sdk-setup-03, 04) |
| 4 | `openspec validate` en `pre-push` | **Skip con aviso** si el CLI no está; la Aduana (fase 3) lo hace obligatorio |
| 5 | Validación de commits | **Bash propio siempre**: cero dependencias (plan §11). El consumidor puede añadir commitlint en su CI si quiere |
| 6 | ¿gitleaks opcional u obligatorio? | **Obligatorio** (decidido el 2026-09-30 en la revisión de la PR 1/3). Sin gitleaks el commit se rechaza con la instrucción de instalación (SC-git-gates-10). La base de patrones en bash se mantiene como segunda red |

Las decisiones 1 y 2 las tomó una persona en el gate Intención, y la 6 en la revisión de la PR 1/3. Las 3 a 5 se cerraron en `tune`
con la propuesta por defecto, que se aceptó sin cambios.
