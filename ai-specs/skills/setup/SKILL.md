---
name: setup
description: Instala o actualiza el nivel Guardia de Spec Sentinel (Centinela + Esclusa) en un repo con un solo comando. Úsala cuando pidan "instala spec sentinel", "instala el SDK", "setup", "pon los guardarraíles en este repo", "actualiza el Centinela/la Esclusa" o al incorporar el SDK a un proyecto nuevo.
---

# setup — el nivel Guardia en un comando

## Overview

Instala el enforcement del SDK en el repo del consumidor: copia `sentinel/`, cablea el Centinela
en `.claude/settings.json`, activa la Esclusa (`core.hooksPath`) y propone el adaptador de stack.
Todo lo hace `setup.sh` (determinista, idempotente y probado en `fixture/install/`). El agente
solo lo ejecuta, interpreta la salida y acompaña a la persona en los pasos pendientes.

## When to Use

- Incorporar el SDK a un repo, o actualizarlo a una versión nueva del SDK (reinstalar es seguro).
- Tras resolver un paso pendiente de una instalación anterior (exit 3), para cerrarla.
- **No** la uses para cambiar reglas de la política ni para desactivar un gate: eso va en un
  cambio OpenSpec revisado por una persona.

## Process

1. **Localiza el SDK y la raíz del repo.** `setup.sh` vive en `<sdk>/ai-specs/skills/setup/`.
   El destino tiene que ser la **raíz** de un repo git (si no, el script falla sin escribir nada).
2. **Ejecuta** `bash <sdk>/ai-specs/skills/setup/setup.sh <raíz-del-repo>` y lee la salida entera.
3. **Interpreta el código de salida**:
   - `0` → instalado. Sigue en el paso 5.
   - `3` → instalado **con pasos pendientes** (líneas `⚠ PENDIENTE`). Paso 4.
   - `1` → error; no se ha dejado nada a medias. Muestra el motivo y para.
4. **Pasos pendientes**: preséntalos a la persona uno a uno, con la instrucción literal del
   script. Los que tocan su máquina o su configuración (instalar gitleaks o jq, encadenar sus
   git hooks, fusionar `sentinel/settings.fragment.json` a mano) **los decide y los hace ella**.
   Después, vuelve al paso 2: la instalación está cerrada cuando el script sale con `0`.
5. **Adaptador de stack**: si hay `sentinel/adapters/stack.proposed.yaml`, enséñaselo a la
   persona. Solo con su visto bueno se renombra a `stack.yaml`. Sin adaptador, la Esclusa omite
   format, lint y tests con aviso, así que no es bloqueante.
6. **Versiona** `sentinel/`, `.claude/settings.json` y `.gitignore` en un commit
   (`chore: install spec sentinel guard level`), en una rama, nunca en una protegida.

## Rationalizations

| Excusa | Contraargumento |
|---|---|
| «Edito yo `.claude/settings.json`, es más rápido» | El script fusiona con jq, hace backup y es idempotente. Una edición a mano duplica entradas o pisa hooks del consumidor |
| «Pongo `core.hooksPath` aunque ya haya hooks» | Dejaría mudos los hooks del consumidor (husky, un escáner corporativo). Se encadenan, no se sustituyen |
| «gitleaks ya lo instalarán» | Sin gitleaks la Esclusa rechaza **todos** los commits. Se resuelve ahora, no en el primer commit |
| «Activo el stack propuesto, se ve bien» | La detección adivina por nombres de scripts. La persona decide qué corre en cada commit |
| «Exit 3 casi es éxito» | Es una instalación incompleta. Hasta que sale con `0`, el nivel Guardia no está garantizado |

## Red Flags

- Ejecutar el script desde un subdirectorio, o sobre un repo distinto del que pidió la persona.
- Ficheros `.bak` o copias de `settings.json` fuera de `sentinel/.backup/`.
- Un `git config core.hooksPath` hecho por el agente: lo hace el script o lo hace la persona
  (la regla `no-hook-disabling` del Centinela lo bloquea, y es correcto).
- `sentinel/.override` o `sentinel/.backup/` en un commit.

## Verification

- `setup.sh` sale con `0` (tras resolver los pendientes) y una segunda ejecución también sale
  con `0` sin cambiar nada.
- `git config --get core.hooksPath` devuelve `sentinel/githooks` (o los hooks del consumidor
  encadenan la Esclusa, si así se decidió).
- Un commit con mensaje no conforme se rechaza (`git commit --allow-empty -m "prueba"`).
- `.claude/settings.json` contiene `sentinel-guard.sh`, `post-edit.sh` y `session-start.sh` una
  sola vez cada uno.
