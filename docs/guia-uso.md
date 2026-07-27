# Guía de uso — Spec Sentinel SDK

> Explicado en simple: qué puede hacer el framework hoy y cómo usarlo, paso a paso.
> **Esta guía crece con cada fase**: cuando una fase se archiva, su sección deja de decir
> "en construcción" y explica lo que ya puedes usar.

## ¿Qué es esto?

Un framework para desarrollar con agentes de IA sin cruzar los dedos: las reglas importantes
no se le *piden* al agente — se hacen **imposibles de saltar**. Se apoya en
[OpenSpec](https://github.com/Fission-AI/OpenSpec): primero se escribe qué debe hacer el
sistema (la *spec*), y el código se valida contra ella.

## ¿Qué puede hacer hoy?

| Capacidad | Estado | Cómo se usa |
|---|---|---|
| Desarrollar con el método SDD (cambios OpenSpec) | ✅ | Sección «El ciclo de trabajo» |
| Saber en qué punto está el proyecto | ✅ | Abre [`STATUS.md`](../STATUS.md) |
| Verificar la salud del framework | ✅ | Sección «Verificar que todo está bien» |
| Guardarraíles que bloquean al agente | 🔜 fase 1 (en curso) | Sección «Guardarraíles» |
| Instalarlo en tu propio proyecto | 🔜 fase 2 | — |
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

**4. Pide revisión y mergea** (con remote: PR con `gh pr create`; sin remote:
`git checkout main && git merge --no-ff feature/<nombre>`).

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

## Guardarraíles 🔜 *(fase 1 — en construcción)*

Lo que hará cuando la fase 1 se archive:

- Las reglas viven en un solo sitio: [`sentinel/policy.yaml`](../sentinel/policy.yaml).
  Cada regla dice qué acción vigila y qué hace: **block** (imposible), **confirm**
  (pide permiso humano) o **warn** (avisa y deja pasar).
- Ejemplos: no se puede commitear en `main`; no se puede tocar el CHANGELOG ni las specs
  archivadas; no se puede meter `.skip()` en un test; `rm -rf` pide confirmación.
- **Vía de emergencia (break-glass)**: si un bloqueo te impide algo legítimo y urgente,
  `SENTINEL_OVERRIDE="motivo" <tu acción>` lo permite **dejando registro auditado** en
  `sentinel/overrides.log`. Sin motivo, no hay override.

## Glosario mínimo

- **Spec** — el contrato: qué debe hacer el sistema, en escenarios verificables.
- **Cambio (change)** — carpeta en `openspec/changes/` con proposal + tasks + spec delta.
- **Archivar** — cerrar un cambio: su spec pasa a `openspec/specs/` (contrato vigente).
- **Fixture** — el banco de pruebas del propio framework (`fixture/`).
- **Gate** — un control que no se puede saltar (hook, git hook o check de CI).
- **Tier** — nivel de adopción: 0 solo guardarraíles · 1 + método SDD · 2 + subagentes.
