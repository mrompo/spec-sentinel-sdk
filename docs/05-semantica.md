# 05 · Semántica del framework — cómo se llama cada cosa y por qué

> **Fuente única del vocabulario.** Un término se define aquí antes de usarse en cualquier
> otro documento. Si un nombre no está en esta página, no es del framework.
> Los identificadores en código (ficheros, ids de regla, `block|confirm|warn`) no cambian:
> aquí nombramos **conceptos**, no ficheros.

## 1. La idea en una frase

**Spec Sentinel convierte reglas que el agente debería seguir en reglas que no puede violar,
y hace que todo cambio nazca de una spec y llegue a producción con rastro.**

Dos modelos lo explican, y son ejes distintos que conviene no mezclar:

- **Las cuatro capas** (§2) — *qué hace* el framework. Es la arquitectura del producto.
- **Los cuatro puestos** (§4) — *cuándo* se hace cumplir una regla. Viven dentro de Shield.

> Por eso a los puestos nunca los llamamos "capas": *capa* es funcionalidad, *puesto* es
> momento de control. Dos cuatros que no se pisan.

## 2. Las cuatro capas

En orden de recorrido: algo se **produce**, se **restringe**, se **juzga** y se **entrega**.

| # | Capa | Pregunta que responde | Qué contiene |
|---|---|---|---|
| 1 | **Engine** | ¿Qué hay que hacer y quién lo hace? | OpenSpec y todo lo que gira alrededor: el ciclo (intake → propose → apply → verify → archive), specs vivas, expedientes, tareas, skills, y los perfiles que **producen** (arquitecto, developer, QA, datos) |
| 2 | **Shield** | ¿Qué no se puede hacer? | Las reglas estrictas: gitflow, conventional commits, ramas protegidas, ficheros gestionados, tests, secretos, aislamiento. Se aplica en cuatro puestos (§4) |
| 3 | **Tribunal** | ¿Esto está bien? | Los perfiles que **evalúan** y sus artefactos: panel adversarial de tres lentes, veredicto `SHIP / CONDITIONAL / HOLD`, informes, revisión de arquitectura |
| 4 | **Delivery** | ¿Cómo llega a producción y qué nos cuesta? | Release por entornos, carril de hotfix, instalación, y la medición: KPIs, bitácora de excepciones, auditoría de ejecuciones del agente, `doctor` |

**La frontera entre Engine y Tribunal es la separación de poderes.** No es una división
estética: quien produce no juzga su propio trabajo. Un perfil pertenece a Engine si escribe, y
a Tribunal si dictamina — y ninguno hace las dos cosas. Esa línea es la que hace creíble el
veredicto.

**Shield es transversal**: no se recorre, se sufre. Actúa sobre lo que hacen Engine y Tribunal
en cada momento del camino.

## 3. Qué aporta cada capa por separado

Cada capa vale por sí sola, y por eso el framework se adopta por niveles:

| Nivel | Nombre | Capas | Qué te llevas |
|---|---|---|---|
| 0 | **Guardia** | Shield | Las reglas dejan de ser opcionales, sin cambiar tu forma de trabajar |
| 1 | **Método** | + Engine | La spec es el contrato y genera la obligación de test |
| 2 | **Equipo** | + Tribunal | Evaluación independiente con separación de poderes |

**Delivery** se activa por partes en cualquier nivel: la instalación desde el nivel 0; release,
hotfix y métricas cuando el equipo los adopte. *(Antes: "Tier 0/1/2".)*

## 4. Los cuatro puestos de Shield

Una regla se puede hacer cumplir en cuatro momentos, y hay un puesto de guardia en cada uno:

```
   INTENCIÓN  ──▶  ACCIÓN  ──▶  REGISTRO  ──▶  INTEGRACIÓN
   qué quiero      qué hago     qué queda      qué comparto
   hacer           ahora        escrito        con el equipo

   ┌─────────┐   ┌───────────┐  ┌──────────┐   ┌─────────┐
   │  CANON  │   │ CENTINELA │  │ ESCLUSA  │   │ ADUANA  │
   └─────────┘   └───────────┘  └──────────┘   └─────────┘
    la doctrina    el guardia     la cámara      la frontera
```

**Por qué cuatro y no uno.** Cada puesto tiene el defecto complementario del siguiente:

| Puesto | Actúa | Coste de fallar | Garantía |
|---|---|---|---|
| **Canon** | Antes de nada | Nulo — corrige la intención | Ninguna: es persuasión |
| **Centinela** | Antes de la acción | Bajo — el agente reintenta bien | Alta contra descuidos, no contra ingenio |
| **Esclusa** | Al escribir la historia | Medio — hay que rehacer el commit | Total sobre lo que se registra |
| **Aduana** | Al integrar | Alto — vuelta atrás y revisión | Total sobre lo que se comparte |

Cuanto **antes** actúa un puesto, más barato y amable es; cuanto **después**, más difícil de
esquivar. Por eso no sobra ninguno: los primeros hacen que el trabajo salga bien, los últimos
garantizan que lo que sale mal no pasa.

### Canon · *canon* — la doctrina
Lo que el agente sabe antes de actuar: estándares, instrucciones (`AGENTS.md`), skills, el
contexto que se le inyecta al arrancar. **Actúa** sobre la intención.
**Límite honesto**: es persuasión, no control. Si una regla importa de verdad, tiene que
existir también más abajo. *(Antes: "capa 1 · prompt".)*

### Centinela · *sentinel* — el guardia
El hook que intercepta cada acción del agente y la evalúa contra **la política**; decide
**bloquea**, **consulta** o **avisa**. **Actúa** justo antes de ejecutar la acción.
**Límite honesto**: *best effort*. Evalúa texto, así que siempre habrá una grafía no prevista;
y evalúa el estado *antes* de ejecutar, lo que abre ventanas (un `checkout` seguido de un
`commit`). No detiene a un adversario con shell: hace imposible el descuido. Detalle en
[`sentinel/README.md`](../sentinel/README.md). *(Antes: "capa 2 · tool".)*

### Esclusa · *lock* — la cámara de paso
Los git hooks. Como una esclusa de canal: para pasar del trabajo en curso a la historia del
repositorio hay que entrar en la cámara y cumplir los requisitos (mensaje conforme, sin
secretos, formato, tests). **Actúa** al registrar (`commit`, `push`).
**Por qué importa**: aquí no hay ventana de esquive — el commit existe o no existe, y da igual
quién lo intentó. Cierra justo lo que el Centinela no puede. *(Antes: "capa 3 · git".)*

### Aduana · *customs* — la frontera
El gate de CI sobre la PR: nada entra en el tronco común sin inspección (lint, estático,
tests, cobertura, secretos, fronteras de arquitectura, validación contra la spec).
**Actúa** al integrar. **Por qué importa**: es el único puesto que no vive en la máquina de
quien hace el cambio — no se puede desinstalar ni "olvidar". *(Antes: "capa 4 · CI".)*

## 5. Artefactos con nombre propio

| Nombre | Fichero | Capa | Qué es |
|---|---|---|---|
| **La política** | `sentinel/policy.yaml` | Shield | Las reglas del Centinela: qué vigila y en qué modo |
| **La llave** | `sentinel/.override` | Shield | Vía de emergencia: un motivo escrito por una persona, de **un solo uso** |
| **La bitácora** | `sentinel/overrides.log` | Delivery | Registro auditado de cada excepción. Sin bitácora escribible, no hay excepción |
| **El banco** | `fixture/` | Engine | Banco de pruebas del propio framework: toda regla dura tiene aquí un test que la falsifica |
| **El contrato** | `openspec/specs/` | Engine | Las specs vigentes: lo que el sistema promete hacer |
| **El expediente** | `openspec/changes/<nombre>/` | Engine | Un cambio en curso: propuesta, tareas y delta de spec |
| **El veredicto** | salida del panel | Tribunal | `SHIP` (adelante) · `CONDITIONAL` (con reservas) · `HOLD` (para) |

## 6. Los tres modos de Shield

| Modo | En código | Qué ocurre |
|---|---|---|
| **Bloquea** | `block` | La acción se deniega con su motivo. Solo la llave la permite |
| **Consulta** | `confirm` | No se ejecuta sin que una persona apruebe **esa** acción |
| **Avisa** | `warn` | Pasa dejando aviso visible (modo de rodaje al instalar) |

## 7. Lo que deliberadamente NO renombramos

Inventar vocabulario tiene un coste: cada palabra nueva es algo que alguien debe aprender.
Estos términos son estándar de la industria y se quedan como están — **spec**, **scenario**,
**commit**, **PR**, **hook**, **gate**, **CI**, **skill**, **agente**, **fixture** (como
concepto técnico; "el banco" es su nombre corto en prosa).

Regla de higiene: **un nombre nuevo solo se justifica si sustituye a una perífrasis que usamos
más de tres veces.** Si no, es jerga.

## 8. Cómo se usa este vocabulario

- Documentación de cara al usuario (README, guía): **los nombres**.
- Plan y specs: los nombres, con la numeración entre paréntesis cuando ayude
  (`Centinela (puesto 2)`), porque el plan razona sobre la escalada de dureza.
- Código, ids y ficheros: **sin cambios** — `sentinel-guard`, `policy.yaml`, `block`.
- Un término nuevo se añade **aquí primero**; el banco verifica que esta página define las
  cuatro capas y los cuatro puestos, y que las superficies principales los usan.
