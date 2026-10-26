# Proposal — sentinel-paths (el Centinela decide sobre lo que se toca, no sobre cómo se escribe)

> Nace de la quinta revisión adversarial de `git-gates` (V5-1, V5-2, A5-3, V5-4, P5-6, V5-7,
> [`../archive/2026-10-20-git-gates/review/round5/README.md`](../archive/2026-10-20-git-gates/review/round5/README.md)). La persona
> decidió el 2026-10-18 sacar lo del Centinela de la PR del instalador a su propio cambio.

## Why

El Centinela decide por el texto de la ruta y fichero a fichero. La revisión lo reprodujo:

- Las **carpetas** protegidas se mueven o se borran enteras (`mv sentinel/hooks …`,
  `git rm -r .claude`) sin bloqueo ni aprobación, mientras que borrar uno de sus ficheros está
  bloqueado. Con la carpeta fuera, el hook sale con 127, que no bloquea, y el Centinela o la
  Esclusa quedan sin efecto (V5-1).
- A través de un **enlace** a `.claude`, `sentinel` o `.git`, Edit y Write tocan los ficheros
  protegidos, porque el guard normaliza `./` y `../` pero no resuelve enlaces (V5-2). Por la
  misma raíz, en la disposición «repo bare + worktrees» (`.bare/config`) la configuración de git
  no está protegida (A5-3), y la de usuario de Claude Code solo lo está en su ruta por defecto
  (`CLAUDE_CONFIG_DIR`, V5-7).
- `core.hooksPath` se cambia desde un comando sin nombrarlo: `git config --remove-section
  core`, o un `include.path` hacia un fichero que el agente escribe (V5-4).
- Al revés, los patrones de la configuración de git no están anclados y bloquean trabajo
  legítimo que el consumidor no puede relajar (`.gitconfig.example`, un repo de dotfiles, leer
  `.git/config`) (P5-6). Es el mismo problema que el falso positivo de solo lectura que ya
  figuraba como deuda en `STATUS.md`.
- El cableado ejecuta el Centinela con el `bash` del `PATH` de la sesión: con una carpeta del
  repo en ese `PATH` (direnv, `npm run`), el Centinela ejecutaría un `bash` que el agente puede
  escribir (A7-2 de la séptima revisión, que la persona trajo aquí el 2026-10-19).
- La llave de un solo uso la gasta la primera acción bloqueada de cualquier agente de la sesión,
  también la de un subagente, y no la que la persona tenía en mente: pasó durante la quinta
  revisión con un comando de solo lectura de un agente revisor.

## What Changes

1. Mover, renombrar o borrar desde la shell una carpeta protegida (`sentinel/`,
   `sentinel/hooks`, `sentinel/githooks`, `.claude/`) se bloquea, como sus ficheros.
2. El guard resuelve la ruta física (la carpeta padre que exista) y decide también sobre ella; la
   configuración de git protegida es la real del repo (`git rev-parse --git-common-dir` y
   `--git-dir`), no la que se llame `.git`, y la de usuario de Claude Code es la de
   `CLAUDE_CONFIG_DIR` si está definida.
3. `no-hook-disabling` cubre las formas de cambiar `core.hooksPath` sin nombrarlo que la revisión
   encontró (`--remove-section`/`--rename-section` de `core`, `include.path`,
   `includeIf.*.path`).
4. Los patrones de la configuración de git se anclan al final del nombre, y leer un fichero
   protegido desde la shell deja de bloquearse cuando el comando solo lee.
5. La llave se ata a la acción que la persona autoriza (p. ej. la ruta o el comando en el
   motivo), o al menos el aviso de bloqueo dice qué acción la gastaría.
6. El cableado ejecuta el Centinela con un entorno que no depende del de la sesión: un `bash`
   y un `PATH` que no salen del repo, sin las variables que cambian cómo arranca bash. Hay que
   cuidar las plataformas sin `/bin/bash` (NixOS).

## Decisiones

Gate **Intención** aprobado el 2026-10-26. En el `tune` del mismo día, la persona eligió:

1. **La llave se ata con `para:` obligatorio** (punto 5). La llave lleva el motivo y una línea
   `para: <acción>`, y solo la gasta la acción cuya descripción coincide exactamente. El aviso
   de bloqueo da la llave de esa acción lista para copiar. Una llave sin `para:` no autoriza
   nada. `SENTINEL_OVERRIDE` vale para toda la sesión y no se ata. La Esclusa usa la misma
   llave con `para: esclusa:<hook>`. La coincidencia es exacta y no por contenido: con
   «contiene», `git diff x; rm -r sentinel` gastaría la llave de `git diff x`.
2. **Para «solo lee» hay una lista cerrada, fail-closed** (punto 4). El comando se parte por
   sus separadores y cada tramo tiene que empezar por un lector conocido, sin redirecciones,
   sustituciones ni opciones que escriben. Ante la duda, el comando se evalúa como hoy. Solo lo
   aplican las reglas que lo declaran (`skip_read_only: true`): `self-protection` y
   `managed-files` lo declaran, `isolation-env` no.
3. **El cableado lleva un entorno limpio y es fail-closed** (punto 6). Usa `env -i` con una
   lista blanca de variables y un `PATH` fijo de carpetas del sistema (incluidas las de NixOS).
   Si el Centinela no existe, no se puede leer o termina con otro código, el cableado sale con 2.
   Esto cierra también el límite «hook ausente = fail-open» de `sentinel/README.md`.
4. **Hay tres PRs** (gate Plan, en `tasks.md`).

Por el camino, el `tune` añadió dos escenarios a los de la proposal:
`CLAUDE_CONFIG_DIR` (SC-sentinel-paths-07) y que el Centinela que no decide bloquea (SC-09).
El de la lectura pasó a SC-08. Además, `.gitconfig` solo se protege como configuración de la
persona: por su ruta en la carpeta personal o porque `~/.gitconfig` enlaza a él.

## Impact

- Capabilities afectadas: `sentinel-guard` (requisitos nuevos; break-glass modificado) y
  `git-gates` (la llave de la Esclusa se ata a un hook). `sdk-setup` no cambia de contrato:
  SC-sdk-setup-09 ya cubre sustituir el cableado de una versión anterior.
- Ficheros protegidos (los aplica una persona con un parche): `sentinel/hooks/sentinel-guard.sh`,
  `sentinel/policy.default.yaml`, `sentinel/githooks/lib/breakglass.sh`, `.claude/settings.json`,
  `sentinel/settings.fragment.json` y el instalador (`ai-specs/skills/setup/setup.sh`).
- El banco gana casos de carpetas, enlaces, repo bare, configuración de git desde comandos,
  `CLAUDE_CONFIG_DIR`, falsos positivos, solo lectura, la llave atada y el cableado. Los casos
  actuales de la llave (Centinela y Esclusa) pasan al formato con `para:`.
- La guía (`docs/guia-uso.md`, la llave) y los límites de `sentinel/README.md` (desaparecen
  «hook ausente» y «PATH de la sesión»; «regex evadibles» suma `cd` dentro de una carpeta
  protegida).
