---
name: spec-sentinel-setup
description: Instala o actualiza el nivel Guardia de Spec Sentinel (Centinela + Esclusa) en un repo con un solo comando. Úsala cuando pidan "instala spec sentinel", "instala el SDK", "setup", "pon los guardarraíles en este repo", "actualiza el Centinela/la Esclusa" o al incorporar el SDK a un proyecto nuevo.
---

# spec-sentinel-setup — el nivel Guardia en un comando

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

1. **Localiza el SDK y la raíz del repo.** `setup.sh` vive en `<sdk>/ai-specs/skills/setup/`
   (expuesta como skill, en `~/.claude/skills/spec-sentinel-setup/`). El destino tiene que ser
   la **raíz** de un repo git (si no, el script falla sin escribir nada). `setup` exige `jq`:
   sin él no instala nada (exit 1) y da la instrucción de instalación.
2. **Ejecuta** `bash <sdk>/ai-specs/skills/setup/setup.sh <raíz-del-repo>` y lee la salida entera.
   Instalar reescribe el enforcement y el cableado, así que lo decide la persona: en la primera
   instalación aún no hay Centinela, así que pídele que lo apruebe antes de ejecutarlo; al
   reinstalar o actualizar, el Centinela le pide la aprobación.
3. **Interpreta el código de salida**:
   - `0` → instalado. Sigue en el paso 5.
   - `3` → instalado **con pasos pendientes** (líneas `⚠ PENDIENTE`). Paso 4.
   - `1` → error. Si falló una comprobación previa no se escribió nada; si falló a mitad, lo
     hecho se queda y volver a ejecutar es seguro. Muestra el motivo y para.
4. **Pasos pendientes**: preséntalos a la persona uno a uno, con la instrucción literal del
   script. Los que tocan su máquina o su configuración (instalar gitleaks, poner las líneas que
   encadenan la Esclusa en sus git hooks, corregir un `.claude/settings.json` que no es JSON
   válido o el evento de `hooks` con una forma inesperada, añadir excepciones al `.gitignore`,
   sacar del índice un `.claude/settings.local.json` versionado (`git rm --cached`), marcar los
   ejecutables con `git add --chmod=+x` si el repo tiene `core.fileMode=false`, quitar un
   `disableAllHooks` o un `env` que llega al Centinela, también de su configuración de usuario,
   corregir los cambios de `openspec/` o decidir `sdd: false`) **los decide y los hace ella**. Lo
   de la configuración gestionada lo resuelve su organización. Después, vuelve al paso 2:
   `setup` reconoce lo que ya está hecho, y la instalación está cerrada cuando sale con `0`.
5. **Adaptador de stack**: si hay `sentinel/adapters/stack.proposed.yaml`, enséñaselo a la
   persona. Solo con su visto bueno se renombra a `stack.yaml`. Sin adaptador, la Esclusa omite
   format, lint y tests con aviso, así que no es bloqueante.
6. **Versiona** la instalación en un commit, en una rama y nunca en una protegida:
   `git add sentinel .claude .gitignore .gitattributes` (nombrar `.claude/settings.json` en un
   comando lo bloquea el Centinela) y `chore: instala spec-sentinel (nivel Guardia)`. Antes del commit,
   revisa con `git status` lo que entra: `.claude/settings.local.json` es de cada persona
   (`setup` lo deja en el `.gitignore`). Si la Esclusa quedó encadenada en hooks versionados
   (husky), versiónalos también.

## Rationalizations

| Excusa | Contraargumento |
|---|---|
| «Edito yo `.claude/settings.json`, es más rápido» | El script fusiona con jq, hace backup y es idempotente. Una edición a mano duplica entradas o pisa hooks del consumidor |
| «Pongo `core.hooksPath` aunque ya haya hooks» | Dejaría mudos los hooks del consumidor (husky, un escáner corporativo). Se encadenan, no se sustituyen |
| «gitleaks ya lo instalarán» | Sin gitleaks la Esclusa rechaza **todos** los commits. Se resuelve ahora, no en el primer commit |
| «Activo el stack propuesto, se ve bien» | La detección adivina por nombres de scripts. La persona decide qué corre en cada commit |
| «Exit 3 casi es éxito» | Es una instalación incompleta. Hasta que sale con `0`, el nivel Guardia no está garantizado |
| «No hay jq: pego el fragmento a mano» | `setup` ya no lo admite: comprobar sin jq un JSON pegado a mano era justo donde daba por bueno un fichero que Claude Code descarta. Instalar jq es un comando |

## Red Flags

- Ejecutar el script desde un subdirectorio, o sobre un repo distinto del que pidió la persona.
- Una sesión de Claude Code abierta en un subdirectorio del repo (un paquete de un monorepo):
  no carga el `.claude/settings.json` de la raíz, así que ahí no hay Centinela.
- Ficheros `.bak` o copias de `settings.json` fuera de `sentinel/.backup/`.
- Un `git config core.hooksPath` hecho por el agente: lo hace el script o lo hace la persona
  (la regla `no-hook-disabling` del Centinela lo bloquea, y es correcto).
- `sentinel/.override` o `sentinel/.backup/` en un commit.

## Verification

- `setup.sh` sale con `0` (tras resolver los pendientes) y una segunda ejecución también sale
  con `0` sin cambiar nada.
- La persona comprueba que `git config --get core.hooksPath` devuelve `sentinel/githooks` (o
  que sus hooks encadenan la Esclusa, si así se decidió). El agente no lo ejecuta: la regla
  `no-hook-disabling` le bloquea cualquier comando que nombre `core.hooksPath`.
- Un commit con mensaje no conforme se rechaza (`git commit --allow-empty -m "prueba"`).
- `.claude/settings.json` contiene `sentinel-guard.sh`, `post-edit.sh` y `session-start.sh` una
  sola vez cada uno (léelo con la herramienta de lectura: un comando de shell que lo nombre lo
  bloquea el Centinela).
- La persona abre una sesión nueva de Claude Code **en la raíz del repo** y comprueba con
  `/hooks` que `sentinel-guard` está cargado. Claude Code descarta entero un settings que no
  valida su esquema, y `setup` no comprueba el esquema completo.
