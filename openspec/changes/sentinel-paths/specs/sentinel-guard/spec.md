# sentinel-guard — Delta spec (sentinel-paths)

## ADDED Requirements

### Requirement: El Centinela decide sobre lo que se toca

El Centinela SHALL proteger el enforcement por lo que la acción toca (carpetas, ruta física,
la configuración de git real del repo, la configuración de Claude Code de la persona) y no
solo por el texto de la ruta.

#### Scenario: Las carpetas protegidas no se mueven ni se borran (SC-sentinel-paths-01)

- **WHEN** el agente mueve, renombra, copia encima, enlaza, cambia los permisos o borra desde la
  shell una carpeta protegida entera (`sentinel`, `sentinel/hooks`, `sentinel/githooks`,
  `sentinel/githooks/lib`, `sentinel/adapters`, `.claude`, `.git/hooks`, `.husky`), con `mv`, `cp`, `rsync`, `ln`, `rm`, `rmdir`, `unlink`, `chmod`,
  `chown`, `git mv` o `git rm`, se escriba como `sentinel`, `sentinel/` o `./sentinel`
- **THEN** el hook deniega la acción, como la de uno de sus ficheros
- **AND** copiar, mover o enlazar a una carpeta (`cp x/config .git`, `cp -t .git x/config`)
  toca, dentro de ella, un fichero con el nombre de cada origen, y se decide como si el
  comando lo nombrara
- **AND** lo mismo con el programa detrás de un prefijo de ejecución o de una asignación
  (`sudo cp`, `env -i cp`, `X=1 cp`), con los orígenes de un comodín (`cp docs/* .git/`), con
  el contenido de una carpeta (`rsync -a x/ .git/`, `cp -r x/. .git/`, `cp -rT x .git`), con
  `-t` dentro de un grupo de opciones (`cp -rt .git x/config`) y con lo que hay dentro de una
  carpeta copiada o enlazada (`cp -r x/.config ~` toca `~/.config/git/config`); una entrada que
  ya está en el destino como enlace toca lo que apunta; una carpeta de más entradas de las que
  el hook comprueba, o que no puede leer entera, se bloquea, y la llave de esa acción lo salva
- **AND** las rutas relativas se resuelven desde la carpeta de la sesión (el `cwd` del tool
  call), no desde la del hook
- **AND** lo mismo si el programa se escribe por su ruta (`/bin/mv`), con una barra delante
  (`\mv`) o entre comillas (`'mv'`), o si el comando lo separa del anterior con un salto de
  línea o un tabulador escritos como escape del JSON: las reglas del comando deciden sobre lo
  que ejecuta bash
- **AND** una comilla dentro de un comentario, escapada dentro de `$'…'` o suelta en el cuerpo
  de un heredoc no esconde las líneas que le siguen
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
- **AND** un `..` detrás de un enlace sube desde donde apunta el enlace, como lo resuelve el
  sistema (`h/../policy.yaml` con `h` enlazado a `sentinel/hooks` es `sentinel/policy.yaml`)

#### Scenario: La configuración de git es la real del repo (SC-sentinel-paths-03)

- **WHEN** el agente edita la configuración de git del repo (`config` y `config.worktree`) o sus
  hooks en una disposición que no los llama `.git` (p. ej. un repo bare con worktrees,
  `.bare/config`), con las herramientas de edición o nombrándolos en un comando
- **THEN** el hook deniega la acción
- **AND** es la configuración del proyecto aunque la sesión esté en otra carpeta, y en un repo
  bare que contiene sus worktrees, lo de cada worktree sigue siendo del repo (sus carpetas
  protegidas lo son) y no de la configuración de git
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
- **AND** detrás de las carpetas del sistema, el `PATH` fijo lleva las que usan como sistema
  Git for Windows (`/mingw64/bin`) y Nix (`/nix/var/nix/profiles/default/bin` y el perfil de la
  persona que gestiona el sistema, `/etc/profiles/per-user/<persona>/bin`), donde puede estar el
  único git de la máquina
- **AND** el `PATH` fijo solo lleva carpetas que el agente no puede modificar: ninguna de la
  persona (`~/.nix-profile/bin`) ni linuxbrew, que es suya, porque un `git` falso ahí diría al
  Centinela otra rama; sin un git en esas carpetas, el cableado bloquea y lo dice
- **AND** `setup` lanza su prueba de humo a través del cableado, tal como queda en
  `.claude/settings.json`: si en esa máquina el cableado no deja pasar una acción inocua, lo dice
  y termina con pendientes

#### Scenario: El Centinela que no decide, bloquea (SC-sentinel-paths-09)

- **WHEN** el script del Centinela no existe o no se puede leer (la carpeta se movió o se
  borró), o el Centinela termina con un código que no es ni 0 ni 2
- **THEN** el cableado sale con 2 y un motivo que dice cómo restaurarlo desde `HEAD`
  (`git checkout HEAD -- sentinel/hooks/sentinel-guard.sh`, que vale también si se borró del
  índice): la acción se bloquea, en vez del 127 que el harness deja pasar
- **AND** si la rama o el commit en que está el proyecto no tiene el Centinela (una rama de
  antes de instalar el SDK, `git bisect`), el motivo no manda restaurarlo, sino volver a la
  rama anterior (`git checkout -`) o integrar la que instala el SDK
- **AND** si el SDK está instalado pero aún sin versionar (`setup` acaba de terminar y no hay
  commit), el motivo no manda restaurarlo ni volver de rama, sino reinstalarlo con `setup`
- **AND** sin un git que responda en el proyecto, el cableado también sale con 2, porque sin la
  rama no se aplicarían las reglas de rama, y el motivo dice por qué: con qué `PATH` buscó git
  (solo carpetas que el agente no puede modificar) y lo que dice (que no lo encuentra; o, en un
  repo de otro dueño, *dubious ownership* y cómo declararlo seguro), sin mandar instalar un git
  que ya está

### Requirement: La rama es la de HEAD, también sin commits

El Centinela SHALL aplicar las reglas de rama a la rama a la que apunta `HEAD`, también en un
repo sin commits.

#### Scenario: El primer commit en una rama protegida (SC-sentinel-paths-10)

- **WHEN** el agente intenta `git commit` en un repo sin commits cuya rama es protegida (p. ej.
  `main` recién creado con `git init`)
- **THEN** el hook deniega por `protected-branches`, como con commits (antes la rama salía como
  `HEAD` y el primer commit en `main` pasaba)
- **AND** en una rama feature sin commits pasa, y con `HEAD` desligado no hay rama y las reglas
  de rama no se aplican

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
  rellenar y su `para:`), así que la persona sabe qué autoriza; copiada tal cual, sin sangría
  que deje el heredoc sin cerrar, y pegada en bash, zsh o sh, escribe la llave
- **AND** el comando del aviso lleva la ruta absoluta de la llave, entrecomillada para la shell:
  pegado desde cualquier carpeta del proyecto, y aunque su ruta tenga espacios o comillas, la
  llave va a la raíz del proyecto; y el agente no puede ejecutarlo
- **AND** con `SENTINEL_OVERRIDE` activo, la excepción sale de la sesión y una llave atada a
  otra acción se conserva; la llave de esta misma acción se gasta, porque si quedara valdría
  para repetirla cuando ya no haya excepción de sesión
- **AND** una acción que contiene la autorizada pero no es ella (`para: Bash:git diff x` frente
  a `git diff x; rm -r sentinel`) no la gasta
