# Proposal — framework-semantics (semántica y nombres del framework)

## Why

El framework ya tiene más piezas de las que un número puede sostener. Hoy decimos "capa 2",
"Tier 1", "el hook", "el fixture" — nombres posicionales que obligan a recordar un índice y
que no dicen **qué hace** cada pieza ni **cuándo** actúa. Tres consecuencias reales:

1. **No se puede explicar rápido.** Contar el framework exige recorrer el plan entero.
2. **La documentación deriva.** Cada documento inventa su propia forma de referirse a lo mismo
   ("hooks de agente", "gobernanza del agente", "capa tool") — la deriva documental que ya
   detectamos en la fuente B, ahora en casa.
3. **Los nombres posicionales mienten al crecer.** "Capa 2" no dice que actúa *antes* de la
   acción, ni que es *best effort*, ni por qué necesita a la 3.

Antes de seguir construyendo (fase 2 en adelante) conviene fijar el vocabulario: es más barato
nombrar cuatro piezas ahora que renombrarlas cuando existan veinte y estén instaladas en
repos ajenos.

## What Changes

1. **`docs/05-semantica.md`** — el vocabulario canónico y la explicación del framework:
   - El **modelo del Loop**: cuatro términos sin solape — **Loop** (la vuelta completa de un
     cambio), **Stage** (Engine · Tribunal · Delivery), **Step** (`propose`, `tune`, `apply`…)
     y **Gate** (la condición para salir de un step) — con **Shield** como capa transversal,
     no como stage.
   - Los **steps y gates de cada stage**, con quién es dueño de cada step y si el gate lo
     cierra código o una persona.
   - Los **caminos de vuelta**: a qué step devuelve cada gate fallado.
   - Los **dos desenlaces de `archive`**: entregado (la delta pasa a contrato) o descartado
     (se archiva con su motivo).
   - El **afinado** como principio: spec, política y Loop se ajustan con el uso.
   - La **cadena**: los cuatro momentos en que se puede intervenir un cambio (intención →
     acción → registro → integración) y por qué hacen falta los cuatro.
   - Nombre, slug en inglés, definición, momento, alcance y **límite honesto** de cada
     puesto de la cadena.
   - Nombres de los niveles de adopción (hoy "Tier 0/1/2") y de los artefactos con nombre
     propio (la política, la bitácora, la llave, el banco).
   - Lista explícita de lo que **no** se renombra, para no fabricar jerga.
2. **Nombres canónicos aplicados** a las superficies de cara al usuario: `README.md`,
   `docs/guia-uso.md`, `sentinel/README.md`, `STATUS.md`.
3. **Check en el banco de pruebas**: la semántica es verificable — el fixture comprueba que
   el modelo del Loop, los stages, Shield y los cuatro puestos (con su slug) están definidos,
   y que las superficies principales los usan.

## What does NOT change

Ninguna regla ni ningún comportamiento. En código solo cambian **comentarios** (cabeceras de
`sentinel-guard.sh` y `policy.yaml` que decían "capa 2"). Los identificadores en código
(`sentinel-guard`, `policy.yaml`, `block|confirm|warn`) **se mantienen**: la semántica nombra
conceptos, no renombra ficheros. La numeración antigua (capas 1-4) sigue siendo válida como referencia en el plan; los
nombres la acompañan, no la sustituyen.

## Impact

- Nuevos: `docs/05-semantica.md`, check de semántica en `fixture/verify.sh`.
- Modificados: README, guía de uso, `sentinel/README.md`, `STATUS.md`, glosario.
- La fase 2 (`git-gates`) queda **aparcada en Propose** en su rama, sin trabajo a medias; se
  retoma después y su documentación nacerá ya con el vocabulario correcto.
