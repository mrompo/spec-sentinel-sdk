# 05 · Semántica del framework — cómo se llama cada cosa y por qué

> **Fuente única del vocabulario.** Un término se define aquí antes de usarse en cualquier
> otro documento. Si un nombre no está en esta página, no es del framework.
> Los identificadores en código (ficheros, ids de regla, `block|confirm|warn`) no cambian:
> aquí nombramos **conceptos**, no ficheros.

## 1. La idea en una frase

**Spec Sentinel convierte reglas que el agente debería seguir en reglas que no puede violar,
y hace que todo cambio nazca de una spec y llegue a producción con rastro.**

## 2. Las cuatro palabras del modelo

El framework no es una pila de capas: es un **bucle** que un cambio recorre. Cuatro términos,
y ninguno se solapa:

| Término | Qué es | Ejemplo |
|---|---|---|
| **Loop** | El recorrido completo. Un cambio le da la vuelta entera | Se mide con el lead time: una vuelta |
| **Stage** | Las grandes etapas que atraviesa | Engine · Tribunal · Delivery |
| **Step** | Lo que ocurre dentro de un stage | `tune`, `apply`, `review`, `release` |
| **Gate** | La condición para salir de un step | Claridad, Verde, Veredicto, Aduana |

**Shield no es un stage**: es transversal. No hay un momento en que "estés en Shield" — está
siempre encendido, dentro de cada step y sobre todo en cada gate.

```
        ┌──────────────── SHIELD (transversal) ────────────────┐
        │      Canon · Centinela · Esclusa · Aduana            │
        │                                                      │
   ┌────▼─────┐   gate    ┌──────────┐   gate    ┌─────────────▼┐
   │  ENGINE  │ ────────▶ │ TRIBUNAL │ ────────▶ │   DELIVERY   │
   │ producir │           │  juzgar  │           │   entregar   │
   └──────────┘           └──────────┘           └──────┬───────┘
        ▲                                                │
        └───────────── archive · métricas ───────────────┘
```

## 3. Los cuatro grandes

| Stage | Responde a | Qué contiene |
|---|---|---|
| **Engine** | ¿Qué hay que hacer y quién lo hace? | OpenSpec y todo su entorno: el ciclo, specs vivas, expedientes, tareas, skills, y los perfiles que **producen** (arquitecto, developer, QA, datos) |
| **Shield** | ¿Qué no se puede hacer? | Las reglas estrictas: gitflow, conventional commits, ramas protegidas, ficheros gestionados, tests, secretos, aislamiento. Se aplica en cuatro puestos (§5) |
| **Tribunal** | ¿Esto está bien? | Los perfiles que **evalúan** y sus artefactos: panel adversarial de tres lentes, veredicto `SHIP / CONDITIONAL / HOLD`, informes |
| **Delivery** | ¿Cómo llega a producción y qué cuesta? | Release por entornos, carril de hotfix, instalación, y la medición: KPIs, bitácora, `doctor` |

**La frontera entre Engine y Tribunal es la separación de poderes.** Un perfil está en Engine
si escribe y en Tribunal si dictamina; ninguno hace las dos cosas. Esa línea es la que hace
creíble el veredicto.

## 4. Los steps y sus gates

⚙️ = lo cierra código determinista · 👤 = lo cierra una persona

### Engine · producir

| Step | Produce | Gate de salida |
|---|---|---|
| `discover` *(condicional)* | Qué se pide de verdad: contexto, afectados, alternativas descartadas | — (alimenta a `tune`) |
| `tune` | Spec al 100%: escenarios falsables, happy path **y** error | **Claridad** 👤 — sin preguntas abiertas · aprueba Producto |
| `design` *(condicional)* | `design.md`: alternativas, trade-offs, contratos, ADRs | **Diseño** 👤 — hay plan antes de teclear · aprueba tech lead |
| `propose` | Expediente: delta spec + tareas en slices + plan de pruebas | **Contrato** ⚙️ — `openspec validate --strict`, ids `SC-*`, slices mergeables por separado |
| `apply` ↺ | Código por slice, TDD, commits atómicos | **Esclusa** ⚙️ — commit conforme, sin secretos, formato, tests del slice |
| `verify` ↺ | Evidencia: suite, cobertura, trazabilidad | **Verde** ⚙️ — tests + cobertura + **spec-coverage del delta** + estático + fronteras |

`apply`↔`verify` es un **bucle interno por slice**: un cambio son varias PRs pequeñas, no una
grande. Los dos steps condicionales son simétricos: una petición clara entra directa en `tune`;
un chore se salta `design`.

### Tribunal · juzgar

| Step | Produce | Gate de salida |
|---|---|---|
| `review` | Hallazgos de tres lentes, independientes | **Contexto limpio** ⚙️ — cada lente ve el diff y la spec, nunca el razonamiento del implementador |
| `counter-review` | Validación cruzada: cada lente ve las otras | — (ronda interna) |
| `synthesis` | Conteo de acuerdos → `SHIP` / `CONDITIONAL` / `HOLD` | **Veredicto** ⚙️ — lo calcula código contando acuerdos, no otra llamada al LLM |
| `disposition` | Qué se hace con cada hallazgo | **Resolución** 👤 — `HOLD` devuelve a Engine · `CONDITIONAL` arquitectónico lo resuelve el arquitecto, el resto una persona |

### Delivery · entregar y medir

| Step | Produce | Gate de salida |
|---|---|---|
| `merge` | El cambio en el tronco común | **Aduana** ⚙️ — gate de CI completo + aprobación humana en la PR |
| `release` | Versión en su canal (`dev` → `-b.N` → estable) | **Promoción** 👤 — QA valida la versión de preproducción |
| `deploy` | Artefacto desplegado | **Smoke** ⚙️ — verde, o rollback |
| `archive` | La delta pasa a contrato vigente | **Cierre** ⚙️ — tareas completas, back-merge hecho, STATUS y guía al día, deuda registrada |
| `measure` | KPIs, bitácora, informe de `doctor` | — (alimenta el siguiente `discover`) |

**El hotfix es el mismo Loop comprimido, no otro Loop**: entra directo en `apply` con
referencia de incidente obligatoria, pasa un Tribunal de una sola ronda y un Delivery rápido.
**Se saltan steps, nunca gates** — el test de reproducción y el smoke siguen siendo
obligatorios, y lo aplazado queda como deuda registrada.

## 5. Los cuatro puestos de Shield

Una regla se puede hacer cumplir en cuatro momentos, y hay un puesto en cada uno:

```
   INTENCIÓN  ──▶  ACCIÓN  ──▶  REGISTRO  ──▶  INTEGRACIÓN
   ┌─────────┐   ┌───────────┐  ┌──────────┐   ┌─────────┐
   │  CANON  │   │ CENTINELA │  │ ESCLUSA  │   │ ADUANA  │
   └─────────┘   └───────────┘  └──────────┘   └─────────┘
    la doctrina    el guardia     la cámara      la frontera
```

| Puesto | Actúa | Coste de fallar | Garantía |
|---|---|---|---|
| **Canon** | Antes de nada | Nulo — corrige la intención | Ninguna: es persuasión |
| **Centinela** | Antes de la acción | Bajo — el agente reintenta bien | Alta contra descuidos, no contra ingenio |
| **Esclusa** | Al escribir la historia | Medio — hay que rehacer el commit | Total sobre lo que se registra |
| **Aduana** | Al integrar | Alto — vuelta atrás y revisión | Total sobre lo que se comparte |

Cuanto **antes** actúa un puesto, más barato y amable es; cuanto **después**, más difícil de
esquivar. Por eso no sobra ninguno.

**Canon** · *la doctrina* — lo que el agente sabe antes de actuar: estándares, `AGENTS.md`,
skills, contexto inyectado al arrancar. *Límite honesto*: es persuasión, no control.
*(Antes: "capa 1 · prompt".)*

**Centinela** · *el guardia* — el hook que intercepta cada acción y la evalúa contra **la
política**; decide **bloquea**, **consulta** o **avisa**. *Límite honesto*: *best effort* —
evalúa texto y evalúa antes de ejecutar, así que hay grafías no previstas y ventanas de tiempo.
Hace imposible el descuido, no detiene a un adversario con shell
([detalle](../sentinel/README.md)). *(Antes: "capa 2 · tool".)*

**Esclusa** · *la cámara de paso* — los git hooks. Para pasar del trabajo en curso a la
historia del repositorio hay que entrar en la cámara y cumplir los requisitos. Aquí **no hay
ventana de esquive**: el commit existe o no existe, y da igual quién lo intentó.
*(Antes: "capa 3 · git".)*

**Aduana** · *la frontera* — el gate de CI sobre la PR: nada entra en el tronco común sin
inspección. Es el único puesto que **no vive en la máquina** de quien hace el cambio.
*(Antes: "capa 4 · CI".)*

> Fíjate en que `Esclusa` y `Aduana` aparecen dos veces: como puestos de Shield y como gates
> del Loop. No es duplicación — **los gates duros son Shield materializándose** en el punto
> exacto del recorrido donde toca.

## 6. El afinado · un principio, no solo un step

`tune` no es una transformación de un tiro: es una conversación iterativa que lleva una
petición de vaga a falsable. Y ese patrón se repite por todo el framework:

| Dónde | Qué se afina | Cómo |
|---|---|---|
| `tune` | La spec | Rondas de interrogación hasta que no queda ambigüedad |
| **Shield** | La política | Las reglas entran en `warn` (rodaje) y pasan a `block` cuando el equipo las asimila |
| **Delivery** | El propio Loop | Los KPIs no son nota: son el mando de ajuste (si sube el % de hotfix, el problema es el ciclo normal, no la urgencia) |

**Nada se acierta a la primera y el framework lo asume.** Es lo contrario de imponer una
configuración perfecta el día uno: specs, reglas y umbrales se afinan con el uso.

## 7. Niveles de adopción

| Nivel | Nombre | Stages | Qué te llevas |
|---|---|---|---|
| 0 | **Guardia** | Shield | Las reglas dejan de ser opcionales, sin cambiar tu forma de trabajar |
| 1 | **Método** | + Engine | La spec es el contrato y genera la obligación de test |
| 2 | **Equipo** | + Tribunal | Evaluación independiente con separación de poderes |

**Delivery** se activa por partes en cualquier nivel: la instalación desde el 0; release,
hotfix y métricas cuando el equipo los adopte. *(Antes: "Tier 0/1/2".)*

## 8. Artefactos con nombre propio

| Nombre | Fichero | Stage | Qué es |
|---|---|---|---|
| **La política** | `sentinel/policy.yaml` | Shield | Las reglas del Centinela: qué vigila y en qué modo |
| **La llave** | `sentinel/.override` | Shield | Vía de emergencia: un motivo escrito por una persona, de **un solo uso** |
| **La bitácora** | `sentinel/overrides.log` | Delivery | Registro auditado de cada excepción. Sin bitácora escribible, no hay excepción |
| **El banco** | `fixture/` | Engine | Banco de pruebas del framework: toda regla dura tiene aquí un test que la falsifica |
| **El contrato** | `openspec/specs/` | Engine | Las specs vigentes: lo que el sistema promete hacer |
| **El expediente** | `openspec/changes/<n>/` | Engine | Un cambio en curso: propuesta, tareas y delta de spec |
| **El veredicto** | salida del panel | Tribunal | `SHIP` · `CONDITIONAL` · `HOLD` |

## 9. Los tres modos de Shield

| Modo | En código | Qué ocurre |
|---|---|---|
| **Bloquea** | `block` | La acción se deniega con su motivo. Solo la llave la permite |
| **Consulta** | `confirm` | No se ejecuta sin que una persona apruebe **esa** acción |
| **Avisa** | `warn` | Pasa dejando aviso visible (modo de rodaje al instalar) |

## 10. Lo que deliberadamente NO renombramos

Cada palabra nueva es algo que alguien debe aprender. Estos términos son estándar y se quedan
como están: **spec**, **scenario**, **commit**, **PR**, **hook**, **gate**, **CI**, **skill**,
**agente**, **fixture** (como concepto técnico; "el banco" es su nombre corto en prosa). Los
steps `propose`, `apply`, `verify` y `archive` son **comandos reales del CLI de OpenSpec**: se
mantienen tal cual.

Regla de higiene: **un nombre nuevo solo se justifica si sustituye a una perífrasis que usamos
más de tres veces.** Si no, es jerga.

Dos términos evitados a propósito: *event loop* (colisiona con el planificador de
JS/Node/asyncio, y ya tenemos eventos de verdad en los hooks) y *fine-tuning* a secas (en
contexto de IA significa reentrenar un modelo; por eso el step es `tune` y en prosa hablamos
de **afinado**).

## 11. Cómo se usa este vocabulario

- Documentación de cara al usuario (README, guía): **los nombres**.
- Plan y specs: los nombres, con la equivalencia antigua entre paréntesis cuando ayude.
- Código, ids y ficheros: **sin cambios** — `sentinel-guard`, `policy.yaml`, `block`.
- Un término nuevo se añade **aquí primero**; el banco verifica que esta página define los
  cuatro stages y los cuatro puestos, y que las superficies principales los usan.
