# Proposal — git-gates (fase 2 · completa el Tier 0 instalable)

## Why

La capa 2 ya bloquea al agente, pero **solo en este repo y solo a mano**: hay que copiar
ficheros y editar `.claude/settings.json` sin equivocarse. Además la capa 2 es *best effort*
(ver `sentinel/README.md §Limitaciones`): el panel adversarial demostró que un TOCTOU de rama
o una grafía de comando no prevista se le escapan. La capa 3 cierra ese hueco porque actúa
**sobre el resultado** (el commit), no sobre la intención — y da igual si el commit lo hizo un
agente, un humano o un script.

Esta fase entrega las dos piezas que convierten el Tier 0 en producto: **git hooks** y un
**instalador de un comando**.

## What Changes

1. **`sentinel/githooks/`** (capa 3), instalables vía `core.hooksPath`:
   - `commit-msg`: Conventional Commits en bash puro (sin Node), con bypass para merges y
     `chore(release)`.
   - `pre-commit`: gitleaks (si está) + `format --check` + `lint` del adaptador, solo sobre staged.
   - `pre-push`: `tests` del adaptador + `openspec validate --strict` (solo Tier 1) + **la rama
     protegida se valida aquí de verdad** (cierra el TOCTOU de la capa 2).
   - Patrón **skip-vs-fail**: herramienta ausente = skip con aviso; entorno roto = fallo duro
     con la instrucción de arreglo.
2. **`sentinel/adapters/stack.yaml`** (renombrado desde el ambiguo `sentinel.yaml`, hallazgo
   #27 del panel): declaración de `format · lint · static · tests · env-ready` del proyecto,
   con autodetección para Node y Laravel.
3. **Skill/instalador `setup`**: un comando instala el Tier 0 en cualquier repo —copia
   `sentinel/`, cablea los hooks del agente **fusionando** `.claude/settings.json` si ya existe
   (sin `jq`: fusión conservadora + backup, y si no es segura, deja el fragmento y explica el
   paso manual), configura `core.hooksPath`, y detecta el stack.
4. **Separación default/usuario** (hallazgo #20): `sentinel/policy.default.yaml` (distribuido,
   se actualiza) vs `sentinel/policy.yaml` (del consumidor, nunca se pisa). `overrides.log`
   sale del paquete y se documenta como append-only del consumidor.
5. **Fixture**: casos de capa 3 (cada hook, incluido skip-vs-fail) e **instalación real en
   `demo-app/`** con un solo comando, verificando que después bloquea.

## Impact

- Nuevos: `sentinel/githooks/{commit-msg,pre-commit,pre-push}`, `sentinel/adapters/stack.yaml`,
  `ai-specs/skills/setup/SKILL.md`, `fixture/githooks/*`, `fixture/install/*`.
- Modificados: `sentinel/policy.yaml` → `policy.default.yaml` + copia local; `post-edit.sh`
  (nuevo nombre del fichero de stack); READMEs; `docs/guia-uso.md` (sección «Instalar en tu
  proyecto»); `.gitignore`.
- Tras esta fase, **este repo usará sus propios git hooks**: los commits que no cumplan
  Conventional Commits dejarán de entrar, para agentes y humanos por igual.

## Decisiones abiertas (para el design gate)

- **Fusión de `.claude/settings.json` sin dependencias**: ¿fusión conservadora en bash, o
  permitir `jq` opcional con fallback a instrucciones manuales? (propuesta: lo segundo — usar
  `jq` si existe, y si no, escribir `sentinel/settings.fragment.json` + instrucción).
- **`openspec validate` en pre-push**: solo si el CLI está instalado (skip-vs-fail) o exigirlo
  en Tier 1 (propuesta: skip con aviso; el CI de fase 3 lo hace obligatorio).
- **commitlint**: bash propio (cero deps, decisión plan §11) vs `@commitlint/cli` cuando el
  proyecto ya sea Node (propuesta: bash siempre; el CI puede añadir commitlint si el consumidor
  quiere).
