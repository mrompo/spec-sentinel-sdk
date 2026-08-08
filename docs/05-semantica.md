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

## 3. Los tres stages y Shield

| Stage | Responde a | Qué contiene |
|---|---|---|
| **Engine** | ¿Qué hay que hacer y quién lo hace? | OpenSpec y todo su entorno: el ciclo, specs vivas, expedientes, tareas, skills, y los perfiles que **producen** (arquitecto, developer, QA, datos) |
| **Tribunal** | ¿Esto está bien? | Los perfiles que **evalúan** y sus artefactos: panel adversarial de tres lentes, veredicto `SHIP / CONDITIONAL / HOLD`, informes |
| **Delivery** | ¿Cómo llega a producción y qué cuesta? | Release por entornos, carril de hotfix, instalación, y la medición: KPIs, bitácora, `doctor` |

Y **Shield**, que no es un stage: es transversal. Impide lo que no se puede hacer —gitflow,
conventional commits, ramas protegidas, ficheros gestionados, tests, secretos, aislamiento— y
se aplica en cuatro puestos (§5), dentro de cada step y en cada gate.

**La frontera entre Engine y Tribunal es la separación de poderes.** Un perfil está en Engine
si escribe y en Tribunal si dictamina; ninguno hace las dos cosas. Esa línea es la que hace
creíble el veredicto.

## 4. Los steps y sus gates

⚙️ = lo cierra código determinista · 👤 = lo cierra una persona

### Engine · producir

| Step | Quién | Produce | Gate de salida |
|---|---|---|---|
| `discover` *(cond.)* | analista + arquitecto | Qué se pide de verdad: contexto, afectados, alternativas descartadas | **Problema** 👤 — sabemos qué problema resolvemos y a quién le duele |
| `propose` | quien detecta la necesidad | **El expediente abierto**: declaración de intenciones | **Intención** 👤 — ¿merece la pena y está justificado? · aprueba Producto |
| `tune` | analista *(con Producto)* | El delta spec afinado: escenarios falsables, happy path **y** error | **Claridad** ⚙️👤 — `openspec validate --strict`, ids `SC-*`, sin preguntas abiertas |
| `design` *(cond.)* | arquitecto | `design.md`: alternativas, trade-offs, contratos, ADRs | **Diseño** 👤 — hay enfoque antes de teclear · aprueba tech lead |
| `breakdown` | orquestador + QA | Tareas en *vertical slices* + plan de pruebas | **Plan** ⚙️👤 — cada slice mergeable por separado, con su criterio de aceptación |
| `apply` ↺ | developer *(+ datos si trigger)* | Código por slice, TDD, commits atómicos | **Esclusa** ⚙️ — commit conforme, sin secretos, formato, tests del slice |
| `verify` ↺ | automático *(sandbox)* | Evidencia: suite, cobertura, trazabilidad | **Verde** ⚙️ — tests + cobertura + **spec-coverage del delta** + estático + fronteras |

`discover` ocurre **antes de que exista el expediente**, así que no tiene dónde escribir: su
resultado aterriza en el «por qué» de la propuesta. Es el único step cuyo producto no es un
fichero propio.

**Por qué `propose` va primero.** No significa "proponer la solución": significa **abrir el
expediente y declarar la intención**. Todo lo demás se escribe *dentro* de él — el delta spec
en `openspec/changes/<n>/specs/…` y el diseño en `openspec/changes/<n>/design.md`. Sin
expediente no hay dónde escribir. *(La regla `design-ownership` que protegerá esa ruta llega
en la fase 6: hoy es una intención documentada en la política, no enforcement.)*

De ahí sale el orden natural: se declara la intención → se afina qué debe hacer el sistema →
se decide cómo → y solo entonces se trocea, porque **no se corta en slices lo que aún no tiene
enfoque técnico**.

El gate de **Intención** es el más barato del Loop: descartar aquí cuesta un párrafo; descartar
en `verify` cuesta el trabajo entero.

`apply`↔`verify` es un **bucle interno por slice**: un cambio son varias PRs pequeñas, no una
grande. Los dos condicionales son simétricos: una petición clara se salta `discover`; un chore
se salta `design` y va de `tune` a `breakdown`.

> `propose` y `archive` son los extremos del expediente: uno lo abre, el otro lo cierra
> convirtiendo su delta en contrato vigente.

### Tribunal · juzgar

| Step | Quién | Produce | Gate de salida |
|---|---|---|---|
| `review` | Auditor · Adversary · Pragmatist | Hallazgos independientes | **Contexto limpio** ⚙️ — ven el diff y la spec, nunca el razonamiento del implementador |
| `counter-review` | las mismas tres | Validación cruzada: cada lente ve las otras | — *(ronda interna)* |
| `synthesis` | código determinista | Conteo de acuerdos → `SHIP` / `CONDITIONAL` / `HOLD` | **Veredicto** ⚙️ — lo calcula código, no otra llamada al LLM |
| `disposition` | arquitecto / dev líder | Qué se hace con cada hallazgo | **Resolución** 👤 — nada se cierra por cansancio |

**Las tres lentes** son ortogonales por diseño: **Auditor** (¿calcula bien? corrección y lógica),
**Adversary** (¿qué puede hacer un hostil? seguridad y abuso) y **Pragmatist** (¿sobrevivirá al
contacto con la realidad? mantenibilidad). Un hallazgo que ven ≥2 lentes es *validado-cruzado*;
uno bloqueante validado-cruzado produce `HOLD`.

### Delivery · entregar y medir

| Step | Quién | Produce | Gate de salida |
|---|---|---|---|
| `merge` | dev líder + CI | El cambio en el tronco común | **Aduana** ⚙️ — gate de CI completo + aprobación humana en la PR |
| `release` | automático *(semantic-release)* | Versión en su canal (`dev` → `-b.N` → estable) | **Promoción** 👤 — QA valida la versión de preproducción |
| `deploy` | automático / DevOps | Artefacto desplegado | **Smoke** ⚙️ — verde, o rollback |
| `archive` | orquestador | **Entregado**: la delta pasa a contrato vigente · **Descartado**: el expediente se cierra con su motivo | **Cierre** ⚙️ — tareas completas, back-merge hecho, STATUS y guía al día, deuda registrada |
| `measure` | `doctor` *(automático)* | KPIs, bitácora, informe | — *(el dato se emite en cada gate; `measure` solo lo lee)* |

**`archive` tiene dos desenlaces.** Un expediente puede cerrarse **entregado** (su delta se
convierte en contrato vigente) o **descartado** (no pasó el gate de Intención, o el equipo
decidió no seguir). Los descartados también se archivan **con su motivo**: es la memoria
institucional más barata que existe — cuando alguien reproponga la misma idea dentro de seis
meses, la respuesta ya está escrita.

**El hotfix es el mismo Loop comprimido, no otro Loop**: entra directo en `apply` con
referencia de incidente obligatoria, pasa un Tribunal de una sola ronda y un Delivery rápido.
**Se saltan steps, nunca gates** — el test de reproducción y el smoke siguen siendo
obligatorios, y lo aplazado queda como deuda registrada.

### Los caminos de vuelta

Un gate que no dice **a dónde te devuelve** no es un gate: es un muro. Cada fallo tiene un
retorno definido, y la distancia del retorno mide lo que cuesta descubrir el problema tarde:

| Gate fallado | Vuelve a | Con qué |
|---|---|---|
| **Problema** | fuera del Loop | No hay problema que resolver — no se abre expediente |
| **Intención** | `archive` *(descartado)* | El expediente se cierra con el motivo. Retorno más barato del Loop |
| **Claridad** | `tune` — o a `discover` si el problema estaba mal entendido | Las preguntas abiertas concretas |
| **Diseño** | `design` — o a `tune` si la spec no soporta ningún diseño viable | Las objeciones del arquitecto |
| **Plan** | `breakdown` | Los slices que no eran mergeables por separado |
| **Esclusa** | no se sale de `apply` | El commit no llegó a existir: se corrige y se recommitea |
| **Verde** | `apply` *(el slice)* | El test en rojo o el escenario sin cobertura |
| **Veredicto `HOLD`** | `apply` — o a `design`/`tune` si el hallazgo es de fondo | Los hallazgos con `fichero:línea` |
| **Resolución** | `apply` | Los `CONDITIONAL` sin resolver bloquean: no se cierran por silencio |
| **Aduana** | `apply` | El job de CI que falló |
| **Promoción** | `apply` *(carril rápido contra `preproduction`)* | Lo que QA rechazó → nueva `-b.N` |
| **Smoke** | rollback inmediato + expediente de hotfix | El síntoma en producción |
| **Cierre** | el paso que falte | Back-merge pendiente, deuda sin registrar, STATUS sin actualizar |
| **Regresión post-merge** *(hotfix)* | propuesta de revert | La suite completa en rojo tras el deploy |

Dos lecturas útiles de esta tabla. Primera: **casi todos los retornos caen en `apply`** — por
eso los slices deben ser pequeños, porque el slice es la unidad de rehacer. Segunda: los
retornos de arriba cuestan un párrafo y los de abajo cuestan un despliegue; **cada gate existe
para que el fallo se descubra en la fila más alta posible**.

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

> **Por qué dos gates se llaman como un puesto.** Casi todos los gates nombran *lo que
> garantizan* (Claridad, Verde, Plan, Veredicto); `Esclusa` y `Aduana` nombran *el mecanismo*,
> porque son puestos de Shield. Es una excepción deliberada: cuando un gate lleva el nombre de
> su puesto, estás leyendo que **ahí no decide una persona ni una convención — decide Shield**.
> La irregularidad es información, no ruido.

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

| Nivel | Nombre | Incluye | Qué te llevas |
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

Se nombran igual en la documentación y en la política — traducirlos solo añadiría un segundo
juego de etiquetas para lo mismo:

| Modo | Qué ocurre |
|---|---|
| `block` | La acción se deniega con su motivo. Solo la llave la permite |
| `confirm` | No se ejecuta sin que una persona apruebe **esa** acción |
| `warn` | Pasa dejando aviso visible (modo de rodaje al instalar) |

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

### Colisiones que asumimos a sabiendas

Ningún nombre está libre. Estas son las que un panel de revisión detectó y decidimos asumir,
documentadas para que nadie las descubra por sorpresa:

| Nombre | Choca con | Por qué lo asumimos |
|---|---|---|
| **Sentinel** | **HashiCorp Sentinel** — policy-as-code con tres niveles de enforcement (`advisory`/`soft-mandatory` con override auditado/`hard-mandatory`) que son casi punto por punto nuestros `warn`/`confirm`/`block` | Es el nombre del producto. Regla: **nunca "Sentinel" a secas, siempre "Spec Sentinel"** |
| **Stage** | El *staging area* de git, los `stages:` de CI, `.env.staging` — los tres presentes en este repo | La jerarquía *stage → step → gate* es la convención que el lector ya conoce |
| **Loop** | *Agent loop* y *human in the loop*, que en 2026 son el significado dominante en nuestro propio nicho | El bucle que describimos es el del cambio, no el del agente; el contexto desambigua |
| **`verify`** | `--no-verify` de git significa lo contrario, y hay un job de CI homónimo | Pendiente: renombrar el job de CI, no el step |

## 11. Cómo se usa este vocabulario

- Documentación de cara al usuario (README, guía): **los nombres**.
- Plan y specs: los nombres, con la equivalencia antigua entre paréntesis cuando ayude.
- Código, ids y ficheros: **sin cambios** — `sentinel-guard`, `policy.yaml`, `block`.
- Un término nuevo se añade **aquí primero**; el banco verifica que esta página define los
  tres stages, Shield y los cuatro puestos, y que las superficies principales los usan.
