# sentinel-guard — Delta spec (sentinel-paths)

## ADDED Requirements

### Requirement: El Centinela decide sobre lo que se toca

El Centinela SHALL proteger el enforcement por lo que la acción toca (carpetas, ruta física,
la configuración de git real del repo, la configuración de Claude Code de la persona) y no
solo por el texto de la ruta.

#### Scenario: Las carpetas protegidas no se mueven ni se borran (SC-sentinel-paths-01)

- **WHEN** el agente mueve, renombra, copia encima, enlaza, cambia los permisos o borra desde la
  shell una carpeta protegida entera (`sentinel`, `sentinel/hooks`, `sentinel/githooks`,
  `.claude`, `.git/hooks`), con `mv`, `cp`, `rsync`, `ln`, `rm`, `rmdir`, `unlink`, `chmod`,
  `chown`, `git mv` o `git rm`, se escriba como `sentinel`, `sentinel/` o `./sentinel`
- **THEN** el hook deniega la acción, como la de uno de sus ficheros
- **AND** lo mismo si el programa se escribe por su ruta (`/bin/mv`), con una barra delante
  (`\mv`) o entre comillas (`'mv'`), o si el comando lo separa del anterior con un salto de
  línea o un tabulador escritos como escape del JSON: las reglas del comando deciden sobre lo
  que ejecuta bash
- **AND** las subcarpetas que no son enforcement siguen libres (p. ej. `mv .claude/skills/a
  .claude/skills/b` o `rm -r sentinel/.backup`)
- **AND** entrar antes en la carpeta (`cd sentinel && rm -r hooks`) es el límite documentado
  «regex evadibles», no parte de esta garantía

#### Scenario: Un enlace no abre un fichero protegido (SC-sentinel-paths-02)

- **WHEN** el agente escribe con Edit, Write, MultiEdit o NotebookEdit a través de un enlace
  (del propio fichero o de una carpeta de su ruta) cuya ruta física es un fichero protegido
  (en `.claude/`, `sentinel/`, la configuración de git o la de Claude Code de la persona)
- **THEN** el hook deniega la acción, como por la ruta directa
- **AND** un enlace cuya ruta física no está protegida sigue libre, y escribir un fichero que
  aún no existe en una carpeta enlazada se decide por la ruta física de esa carpeta

#### Scenario: La configuración de git es la real del repo (SC-sentinel-paths-03)

- **WHEN** el agente edita la configuración de git del repo (`config` y `config.worktree`) o sus
  hooks en una disposición que no los llama `.git` (p. ej. un repo bare con worktrees,
  `.bare/config`), con las herramientas de edición o nombrándolos en un comando
- **THEN** el hook deniega la acción
- **AND** lo mismo cuando cambia `core.hooksPath` desde un comando sin nombrarlo: borrando o
  renombrando la sección `core` (`git config --remove-section core`, `--rename-section core`,
  y sus subcomandos sin guiones, `remove-section` y `rename-section`), con un `include.path` o
  un `includeIf.<condición>.path` (también tras un `=`: `--config-env=include.path=…`,
  `GIT_CONFIG_KEY_0=include.path`), o abriendo la configuración en un editor (`git config
  --edit`, `git config edit`)
- **AND** las claves se reconocen en cualquier caja (`core.hookspath`, `include.PATH`), como
  las lee git

#### Scenario: La configuración de Claude Code de la persona, donde esté (SC-sentinel-paths-07)

- **WHEN** Claude Code corre con `CLAUDE_CONFIG_DIR` apuntando a otra carpeta y el agente
  edita `$CLAUDE_CONFIG_DIR/settings.json` (o lo nombra en un comando)
- **THEN** el hook deniega la acción, como con la ruta por defecto (`~/.claude/settings.json`)

### Requirement: Lo que solo se parece no se bloquea

Las reglas de ruta del enforcement SHALL bloquear lo que es enforcement, no lo que se le
parece, y leer un fichero protegido SHALL no bloquearse cuando la regla lo permite y el
comando solo lee. Ante la duda, el comando SHALL evaluarse como hasta ahora (fail-closed).

#### Scenario: Lo que solo se parece no se bloquea (SC-sentinel-paths-04)

- **WHEN** el agente edita un fichero que solo se parece a la configuración de git: un nombre
  que la contiene (`docs/.gitconfig.example`, `.git/config.bak`), o un `.gitconfig` que no es
  el de la persona (`dotfiles/.gitconfig` en un repo de dotfiles)
- **THEN** el hook deja pasar la acción
- **AND** la configuración de git de la persona (`~/.gitconfig`, `~/.config/git/config`, por
  `~`, `$HOME` o la ruta de su carpeta personal) sigue bloqueada, también cuando es un enlace:
  si `~/.gitconfig` enlaza a `dotfiles/.gitconfig`, ese fichero es la configuración real y se
  bloquea

#### Scenario: Leer desde la shell no se bloquea (SC-sentinel-paths-08)

- **WHEN** el agente ejecuta un comando que solo lee un fichero protegido por `self-protection`
  o `managed-files` (p. ej. `tail -3 sentinel/overrides.log`, `grep -n x
  openspec/specs/a/spec.md`, `git diff main -- sentinel/policy.yaml`, `cat .git/config`)
- **THEN** el hook deja pasar la acción
- **AND** «solo lee» es una lista cerrada: cada tramo del comando (separado por `;`, `&&`, `||`,
  `|`, `&` o un salto de línea fuera de comillas, como lo parte bash: `grep -E 'a|b'` es un
  solo tramo) empieza por un lector conocido (`cat`, `head`, `tail`, `wc`,
  `grep`, `ls`, `stat`, `diff`, `cmp`, `cut`, `tr`, `nl`, `echo`, `printf`, `true`, `cd`, y
  `git` con `diff`, `log`, `show`, `status`, `blame`, `ls-files`, `rev-parse` o `cat-file`, sin
  opciones globales), no hay redirecciones (salvo a `/dev/null` y `2>&1`, también junto a un
  separador), sustitución de comandos (`$(`, comillas invertidas), sustitución de procesos
  (`<(`, `>(`), asignaciones de variables (tampoco `printf -v`) ni opciones que escriben
  (`--output`)
- **AND** un comando que escribe, aunque empiece leyendo (`cat x > sentinel/policy.yaml`,
  `tail log | tee sentinel/.override`, `cat $(…)`), sigue bloqueado
- **AND** solo lo aplican las reglas que lo declaran (`skip_read_only: true`): leer un entorno
  productivo sigue bloqueado (`isolation-env`)

### Requirement: El cableado no depende del entorno de la sesión

El cableado SHALL ejecutar el Centinela del repo con un intérprete y un entorno que no salen
del repo ni de la sesión, y SHALL bloquear cuando el Centinela no puede decidir.

#### Scenario: El entorno de la sesión no elige el Centinela (SC-sentinel-paths-06)

- **WHEN** Claude Code se abre con una carpeta del repo en el `PATH` y el agente ha escrito ahí
  un `bash` (o un `grep`, `sed`, `git`), o con variables que cambian cómo arranca bash o qué
  ejecuta (`BASH_ENV`, `ENV`, `SHELLOPTS`, `BASHOPTS`, `BASH_FUNC_*`) o qué configuración lee
  git (`GIT_DIR`, `GIT_CONFIG_*`)
- **THEN** el cableado ejecuta el Centinela del repo con un `PATH` fijo de carpetas del sistema
  (también las de NixOS, que no tiene `/bin/bash`) y sin más variables que las que necesita
  (`HOME`, `CLAUDE_PROJECT_DIR`, `CLAUDE_CONFIG_DIR`, `SENTINEL_OVERRIDE`), y el Centinela
  decide como sin ese entorno

#### Scenario: El Centinela que no decide, bloquea (SC-sentinel-paths-09)

- **WHEN** el script del Centinela no existe o no se puede leer (la carpeta se movió o se
  borró), o el Centinela termina con un código que no es ni 0 ni 2
- **THEN** el cableado sale con 2 y un motivo que dice cómo restaurarlo: la acción se bloquea,
  en vez del 127 que el harness deja pasar

## MODIFIED Requirements

### Requirement: Break-glass auditado

El hook SHALL permitir una acción bloqueada cuando exista un motivo de excepción —token de un
solo uso `sentinel/.override` (vía recomendada, no creable por el agente) o `SENTINEL_OVERRIDE`
en el entorno de la sesión— y SHALL registrar `timestamp · id de regla · acción · motivo` en
`sentinel/overrides.log`. Si el registro no puede escribirse, la excepción SHALL denegarse.
La llave SHALL atarse a una acción: además del motivo, lleva una línea `para: <acción>`, y
solo la gasta la acción cuya descripción coincide exactamente (`<tool>:<ruta relativa>` o
`Bash:<comando>`, la misma que da el aviso de bloqueo). `SENTINEL_OVERRIDE`, que vale para
toda la sesión, no se ata.

#### Scenario: Override con motivo (SC-sentinel-guard-08)

- **WHEN** una acción bloqueada se reintenta con una llave con motivo y `para:` con esa acción,
  o con `SENTINEL_OVERRIDE` con un motivo
- **THEN** la acción se ejecuta, `overrides.log` gana una línea con regla, acción y motivo, y la
  llave desaparece

#### Scenario: Override sin motivo — sigue bloqueado (SC-sentinel-guard-09)

- **WHEN** no hay motivo (variable vacía y sin token, o una llave que solo tiene `para:`)
- **THEN** la acción bloqueada sigue bloqueada

#### Scenario: La llave autoriza la acción prevista (SC-sentinel-paths-05)

- **WHEN** hay una llave y otra acción bloqueada (de cualquier agente de la sesión, también un
  subagente) llega antes que la que la persona autorizó, o la llave no tiene `para:`
- **THEN** esa acción sigue bloqueada y la llave se conserva
- **AND** el aviso de bloqueo da, lista para copiar, la llave de **esa** acción (motivo por
  rellenar y su `para:`), así que la persona sabe qué autoriza
- **AND** una acción que contiene la autorizada pero no es ella (`para: Bash:git diff x` frente
  a `git diff x; rm -r sentinel`) no la gasta
