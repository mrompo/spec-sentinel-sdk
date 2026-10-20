# Proposal — sentinel-paths (el Centinela decide sobre lo que se toca, no sobre cómo se escribe)

> Nace de la quinta revisión adversarial de `git-gates` (V5-1, V5-2, A5-3, V5-4, P5-6, V5-7,
> [`../git-gates/review/round5/README.md`](../git-gates/review/round5/README.md)). La persona
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

## Impact

- Capability afectada: `sentinel-guard`.
- Ficheros: `sentinel/hooks/sentinel-guard.sh` y `sentinel/policy.default.yaml` (protegidos: los
  aplica una persona o con la llave).
- El banco gana casos de carpetas, enlaces, repo bare, configuración de git desde comandos,
  falsos positivos y la llave atada a una acción.
