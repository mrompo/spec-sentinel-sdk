# Proposal — pr-format (formato de las pull requests)

## Why

La PR es donde se cierra el gate **Aduana**: CI en verde **y** una persona que aprueba. Pero
hoy el framework no dice qué debe contener una PR para que esa persona pueda aprobar con
criterio. La guía solo dice `gh pr create`. La primera PR real del repo
([#1](https://github.com/mrompo/spec-sentinel-sdk/pull/1)) lo dejó a la vista: la descripción
explicaba el cambio, pero no enlazaba su expediente, no decía en qué punto del Loop estaba, no
mapeaba los escenarios a sus tests y no declaraba qué parte había escrito un agente.

Tres consecuencias:

1. **El revisor reconstruye el contexto a mano.** Tiene que buscar el expediente, leer
   `tasks.md` y adivinar qué gates se pasaron. La aprobación humana del gate Aduana se vuelve
   un trámite en lugar de un juicio.
2. **La trazabilidad spec → test se pierde en la PR.** Es justo lo que medirá `spec-coverage`
   (fase 3), y conviene que el formato ya tenga dónde ponerla.
3. **La procedencia IA no consta.** En un framework cuyo objetivo es gobernar agentes, que una
   PR no diga qué hizo el agente y qué la persona es un agujero. Además, el plan (§10, fase 5)
   ya preveía una "PR template con procedencia IA".

Cada PR sin formato genera más trabajo para arreglar después. Definirlo ahora, con una sola PR
en el historial, es lo más barato.

## What Changes

1. **Formato de PR**, con dos piezas:
   - **Título**: Conventional Commits (`tipo(ámbito): descripción`), el mismo criterio que la
     Esclusa aplicará a los commits.
   - **Cuerpo**: estas secciones, en este orden. Una sección que no aplica se deja con
     `N/A — <motivo>`; **nunca se borra**.

     | # | Sección | Qué responde | Obligatoria |
     |---|---|---|---|
     | 1 | **Expediente** | ¿De qué cambio OpenSpec sale? Enlace, fase del roadmap, slice `n/m` | Siempre (salvo exentas) |
     | 2 | **Posición en el Loop** | ¿Qué gates se han cerrado ya y cuál cierra esta PR? | Siempre |
     | 3 | **Qué cambia y por qué** | El cambio en 3-6 puntos, para una persona | Siempre |
     | 4 | **Escenarios** | Cada `SC-*` del delta → el test o check que lo cubre → estado | Si el expediente tiene delta |
     | 5 | **Qué NO cambia** | Comportamiento, contratos o ids que se mantienen. Avisa si se toca el propio enforcement de Shield | Siempre |
     | 6 | **Verificación** | Qué se ha ejecutado y con qué resultado (banco, `openspec validate`, CI) | Siempre |
     | 7 | **Riesgos y vuelta atrás** | Qué puede salir mal y cómo se revierte | Siempre |
     | 8 | **Excepciones y deuda** | Usos de la llave (líneas de la bitácora), deuda registrada en `STATUS.md` | Siempre (`ninguna` es válido) |
     | 9 | **Procedencia** | Qué hizo el agente (y qué modelo) y qué la persona; quién revisó | Siempre |
     | 10 | **Foco de la revisión** | Dónde debe mirar el revisor, en 1-3 puntos | Siempre |

   - **PRs exentas del expediente**: `chore(release): …` y los back-merges entre ramas de
     entorno. El formato de título sigue aplicándose.
2. **`.github/pull_request_template.md`**: la plantilla con las diez secciones y una línea de
   ayuda en cada una. GitHub la precarga al abrir una PR desde la web; con `gh pr create` se usa
   con `--body-file` o `--template`.
3. **`docs/guia-uso.md`**: el paso «4. Pide revisión y mergea» pasa a explicar el formato y
   enlaza la plantilla.
4. **El banco**: un check que falsifica la plantilla. Si le falta cualquiera de las diez
   secciones, `fixture/verify.sh` falla.
5. **PR #1**: su descripción se reescribe con este formato como primer uso real (dogfooding).

## What does NOT change

- **No se valida todavía el cuerpo de cada PR en CI.** Comprobar que una PR concreta cumple el
  formato es trabajo de la **Aduana**, y llega con `ci-gate` (fase 3). Aquí solo se define el
  contrato y el banco verifica la plantilla, igual que la política existió antes que el
  Centinela.
- Ninguna regla del Centinela ni de la política.

## Impact

- Nuevos: `.github/pull_request_template.md`, check de plantilla en `fixture/verify.sh`.
- Modificados: `docs/guia-uso.md` (paso 4), `STATUS.md`, `docs/01-plan-maestro.md` (la
  plantilla sale de la fase 5 porque se adelanta aquí; en la fase 5 queda solo la procedencia
  **automática**, sacada de los metadatos del agente).
- Fuera de roadmap, como `framework-semantics`: prepara la fase 3.

## Cuestiones para el gate Intención

1. **¿Diez secciones son demasiadas?** *Propuesta*: sí son muchas, pero siete de ellas son de
   una o dos líneas y el `N/A — motivo` hace barato no aplicar. Quitar alguna deja sin
   respuesta una pregunta que el revisor se va a hacer igual.
2. **Idioma**: secciones en castellano, como toda la documentación del repo (*propuesta*),
   frente a inglés pensando en repos ajenos que instalen el SDK. La plantilla del consumidor se
   podrá traducir cuando `setup` la distribuya.
3. **¿Procedencia a mano o automática?** *Propuesta*: a mano ahora (el agente la rellena al
   abrir la PR) y automática en la fase 5.
