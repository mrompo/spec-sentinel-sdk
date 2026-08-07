# Guía de uso — Spec Sentinel SDK

> Explicado en simple: qué puede hacer el framework hoy y cómo usarlo, paso a paso.
> **Esta guía crece con cada fase**: cuando una fase se archiva, su sección deja de decir
> "en construcción" y explica lo que ya puedes usar.

## ¿Qué es esto?

Un framework para desarrollar con agentes de IA sin cruzar los dedos: las reglas importantes
no se le *piden* al agente — se hacen **imposibles de saltar**. Se apoya en
[OpenSpec](https://github.com/Fission-AI/OpenSpec): primero se escribe qué debe hacer el
sistema (la *spec*), y el código se valida contra ella.

Tiene cuatro capas (nombres y definiciones en [la semántica](05-semantica.md)):

| Capa | Para qué |
|---|---|
| **Engine** | El método: escribir la spec, partirla en tareas, implementarla y verificarla |
| **Shield** | Las reglas estrictas que nadie —ni el agente— puede saltarse |
| **Tribunal** | La evaluación independiente del trabajo hecho |
| **Delivery** | El camino a producción y su medición |

## ¿Qué puede hacer hoy?

| Capacidad | Estado | Cómo se usa |
|---|---|---|
| Desarrollar con el método SDD (cambios OpenSpec) | ✅ | Sección «El ciclo de trabajo» |
| Saber en qué punto está el proyecto | ✅ | Abre [`STATUS.md`](../STATUS.md) |
| Verificar la salud del framework | ✅ | Sección «Verificar que todo está bien» |
| Guardarraíles que bloquean al agente | ✅ | Sección «Guardarraíles» |
| Instalarlo en tu propio proyecto | 🔄 fase 2 (en curso) | — |
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

Marca la tarea con `- [x]` en el `tasks.md`. El progreso real vive ahí.

**4. Pide revisión y mergea.** Con remote: `gh pr create`. Sin remote, el merge a `main` lo
hace **una persona en su terminal** (el agente tiene bloqueadas las ramas protegidas — es la
regla funcionando, no un fallo):

```bash
git checkout main && git merge --no-ff feature/<nombre>
```

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

## Shield · las reglas estrictas

Las reglas viven en un solo sitio, **la política**
([`sentinel/policy.yaml`](../sentinel/policy.yaml)). Hoy se aplican en el puesto del
**Centinela** (el hook que intercepta cada acción del agente); la **Esclusa** (git hooks) y la
**Aduana** (CI) llegan en las fases 2 y 3. Cada regla vigila una acción y decide en uno de
tres modos:

| Modo | Qué pasa |
|---|---|
| **block** | El agente no puede: la acción se deniega con el motivo explicado |
| **confirm** | No se ejecuta sin aprobación humana explícita |
| **warn** | Pasa, pero deja un aviso visible |

**Reglas activas hoy**: no commitear en ramas protegidas (`main`, `development`,
`preproduction`, `production`) · no force-push · no editar CHANGELOG, lockfiles ni specs
archivadas · no meter `.skip()`/`.only()` en tests · aviso al tocar config de cobertura ·
aviso al editar `src/` sin cambio activo (solo Tier 1) · `rm -rf`/`DROP`/`reset --hard` piden
confirmación · nada de `.env` de producción.

**Cómo añadir una regla**: edita `policy.yaml` (id único + qué vigila + `mode` + `reason`) y
añade su caso en `fixture/hooks/cases/`. Sin test, la regla no entra.

**Si un bloqueo te frena** (vía de emergencia auditada). Escribe el motivo en un fichero
**desde tu terminal** (el agente no puede crearlo: está protegido):

```bash
echo "hotfix INC-123 aprobado por tech lead" > sentinel/.override
```

El siguiente bloqueo se permite, se consume el token (**un solo uso**) y queda la línea en
`sentinel/overrides.log` con fecha, regla, acción y motivo. Si el registro no se puede
escribir, la excepción **se deniega**: sin auditoría no hay excepción.

Para toda una sesión (úsalo con cuidado, afecta a todas las reglas):
`SENTINEL_OVERRIDE="motivo" claude` al arrancar.

Los modos `confirm` no necesitan override: el propio Claude Code te pide la aprobación de
**esa** acción concreta.

**Qué más hacen los hooks**: al arrancar sesión el agente recibe la rama y el cambio activo
sin pedirlo; tras cada edición, el fichero se autoformatea si tu proyecto declara un comando
`format` en `sentinel.yaml` (si no, no pasa nada).

## Glosario mínimo

Vocabulario completo y razonado en **[docs/05-semantica.md](05-semantica.md)**. Lo esencial:

- **Engine · Shield · Tribunal · Delivery** — las cuatro capas: producir · restringir · juzgar · entregar.
- **Canon · Centinela · Esclusa · Aduana** — los cuatro puestos donde Shield se aplica:
  la intención, la acción, el commit y el merge.
- **Spec** — el contrato: qué debe hacer el sistema, en escenarios verificables.
- **Expediente** — un cambio en curso en `openspec/changes/` (proposal + tasks + delta).
- **Archivar** — cerrar un expediente: su spec pasa a ser contrato vigente.
- **El banco** — el banco de pruebas del propio framework (`fixture/`).
- **La llave / la bitácora** — la vía de emergencia auditada y su registro.
- **Niveles**: Guardia (solo Shield) · Método (+ Engine) · Tribunal (+ evaluación).
