# sentinel-guard Specification

## Purpose

El Centinela: el hook PreToolUse que evalúa cada acción del agente contra la política del SDK y
la del proyecto. Según la regla más estricta que coincida, la bloquea, pide confirmación humana
o avisa. Protege el propio enforcement y admite una excepción auditada de un solo uso.
## Requirements
### Requirement: Evaluación de la política

El hook `sentinel-guard` SHALL leer cada tool call (JSON por stdin) y evaluar la política
distribuida (`sentinel/policy.default.yaml`, viene con el SDK y la actualiza `setup`) y la del
consumidor (`sentinel/policy.yaml`, nunca se pisa). De todas las reglas que matchean, en las
dos políticas, SHALL ganar la decisión más estricta (`block` > `confirm` > `warn`) y, a
igualdad, la primera (las del SDK van antes que las del consumidor): ninguna regla que solo
confirma o avisa tapa un bloqueo, esté donde esté. El consumidor SHALL poder **añadir**
protección, nunca quitarla. `sdd:` SHALL leerse de la política del consumidor y, si no lo
declara, de la distribuida.

#### Scenario: Acción sin regla — pasa (SC-sentinel-guard-01)

- **WHEN** la acción no matchea ninguna regla de ninguna de las dos políticas
- **THEN** el hook sale con exit 0 y la acción se ejecuta

#### Scenario: Política ilegible — fail-closed (SC-sentinel-guard-02)

- **WHEN** `policy.default.yaml` no existe o no parsea, o `policy.yaml` existe pero no parsea
- **THEN** el hook deniega (exit 2) explicando cómo arreglar la política — nunca pasa en
  silencio. Que el consumidor no tenga `policy.yaml` es legítimo: protegen las reglas del SDK

#### Scenario: El consumidor añade reglas (SC-sentinel-guard-17)

- **WHEN** `policy.yaml` declara una regla propia que ninguna regla del SDK cubre
- **THEN** esa regla se aplica igual que una del SDK

#### Scenario: El consumidor no relaja el SDK (SC-sentinel-guard-18)

- **WHEN** `policy.yaml` declara una regla `warn` que matchea una acción que el SDK bloquea
  (p. ej. `git push --force`)
- **THEN** decide la regla del SDK: la acción se bloquea

#### Scenario: Id duplicado entre políticas (SC-sentinel-guard-19)

- **WHEN** `policy.yaml` declara una regla con el mismo `id` que una de `policy.default.yaml`
- **THEN** el hook deniega como error de política, explicando que las reglas del SDK no se
  sustituyen desde la del consumidor

#### Scenario: Un aviso del SDK no tapa un bloqueo del consumidor (SC-sentinel-guard-20)

- **WHEN** una acción matchea una regla `warn` o `confirm` del SDK y una `block` del consumidor
  (p. ej. editar `jest.config.js`, que el SDK solo avisa, o `rm -rf build`, que solo confirma)
- **THEN** la acción se bloquea por la regla del consumidor
- **AND** una regla `confirm` del consumidor gana a una `warn` del SDK

### Requirement: Modo block

Una regla con `mode: block` SHALL denegar la acción con exit 2 y el motivo por stderr.

#### Scenario: Commit en rama protegida (SC-sentinel-guard-03)

- **WHEN** el agente intenta `git commit` estando en `main`/`development`/`preproduction`/`production`
- **THEN** el hook deniega con el motivo y la instrucción de crear rama

#### Scenario: Edición de fichero gestionado (SC-sentinel-guard-04)

- **WHEN** el agente intenta editar `CHANGELOG.md`, un lockfile o `openspec/specs/**`
- **THEN** el hook deniega indicando qué tooling gestiona ese fichero

#### Scenario: Debilitar la suite de tests (SC-sentinel-guard-05)

- **WHEN** el agente intenta introducir `.skip(`/`.only(`/`xdescribe` en un fichero de test
- **THEN** el hook deniega (protect-tests)

### Requirement: Modo confirm

Una regla con `mode: confirm` SHALL impedir que la acción se ejecute sin aprobación humana
explícita.

#### Scenario: Comando destructivo (SC-sentinel-guard-06)

- **WHEN** el agente intenta `rm -rf`, `DROP TABLE` o `git reset --hard`
- **THEN** la acción no se ejecuta hasta que un humano la aprueba expresamente

### Requirement: Modo warn

Una regla con `mode: warn` SHALL dejar pasar la acción registrando un aviso visible.

#### Scenario: Regla en warn (SC-sentinel-guard-07)

- **WHEN** la acción matchea una regla con `mode: warn`
- **THEN** el hook sale con exit 0 y el aviso queda visible para el agente y el humano

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
- **AND** el `para:` y la acción se comparan sin los espacios del final: la llave del aviso de
  una acción que acaba en espacio la autoriza y, con `SENTINEL_OVERRIDE`, se gasta igual
- **AND** una acción que contiene la autorizada pero no es ella (`para: Bash:git diff x` frente
  a `git diff x; rm -r sentinel`) no la gasta

### Requirement: El enforcement se protege a sí mismo

La política SHALL bloquear toda modificación o borrado del propio enforcement (hooks, las dos
políticas, log de overrides, cableado de la herramienta) y todo intento de desactivar los gates
(`--no-verify`, `core.hooksPath` desde un comando o editando la configuración de git, cualquier
variable `SENTINEL_*` fijada desde un comando).
Ejecutar el instalador SHALL requerir aprobación humana: reescribe el enforcement y el cableado.

#### Scenario: Desarmar el guard — bloqueado (SC-sentinel-guard-13)

- **WHEN** el agente intenta escribir o borrar `sentinel/hooks/*`, `sentinel/policy.yaml`,
  `sentinel/policy.default.yaml`, `sentinel/overrides.log`, `.claude/settings.json`, el
  instalador con las herramientas de edición (`ai-specs/skills/setup/setup.sh` y `chain.sh`,
  también por el enlace de la skill, `~/.claude/skills/spec-sentinel-setup/`; desde la shell
  pide aprobación, SC-sentinel-guard-21), el fragmento de cableado
  (`sentinel/settings.fragment.json`), los hooks donde queda encadenada la Esclusa
  (`.husky/<hook>`, `.git/hooks/`) o la configuración de git donde vive `core.hooksPath`
  (`.git/config`, la de un worktree o un submódulo, `~/.gitconfig`, `~/.config/git/config`), la
  configuración de jq de la persona que lee el instalador (`~/.jq`, no un `.jq` de un proyecto),
  ejecutar `git commit --no-verify`, tocar `core.hooksPath` desde un comando o fijar una
  variable `SENTINEL_*` en un comando (p. ej. `SENTINEL_POLICY_DEFAULT=` o `SENTINEL_SETUP_JQ=`)
- **THEN** el hook deniega la acción
- **AND** otras grafías de esas asignaciones y de `core.hooksPath` son el límite documentado
  «regex evadibles» (decisión de la persona del 2026-10-16), no parte de esta garantía

#### Scenario: Instalar es una decisión humana (SC-sentinel-guard-21)

- **WHEN** el agente ejecuta el instalador (`ai-specs/skills/setup/setup.sh`, con `bash` o
  directamente, también por la ruta del enlace de la skill que recomienda la guía,
  `~/.claude/skills/spec-sentinel-setup/`) o cualquier comando de shell que nombre el instalador
  (`setup.sh` o `chain.sh` en esas dos rutas)
- **THEN** el hook pide aprobación humana (`confirm`): la persona ve el comando antes de que se
  ejecute. Leerlo con las herramientas de lectura no la pide; escribirlo con las de edición se
  bloquea (SC-sentinel-guard-13)
- **AND** si el mismo comando incluye una acción que el SDK bloquea, se bloquea: pedir
  aprobación para instalar no rebaja ninguna otra regla
- **AND** la regla reconoce las formas habituales de lanzarlo; las rebuscadas son el límite
  documentado «regex evadibles» (la protección la dan la comprobación del cableado y que el
  instalador esté protegido)
- **AND** una skill propia del consumidor que se llame `setup` (p. ej.
  `.claude/skills/setup/setup.sh`) no es el instalador del SDK: se edita y se ejecuta sin
  aprobación

### Requirement: Robustez de la política

Una política malformada SHALL producir un error explícito, nunca permiso silencioso: sin
reglas, con una regla sin `mode:` o con una regex inválida, el hook deniega explicando el
arreglo. Los comentarios no SHALL alterar las reglas.

#### Scenario: Política degradada — fail-closed (SC-sentinel-guard-14)

- **WHEN** la política tiene `rules:` vacío, una regla sin `mode:`, una regex inválida, o un
  comentario indentado que menciona una clave
- **THEN** el hook deniega con el motivo concreto (o ignora el comentario), nunca pasa en silencio

### Requirement: Alcance del matching

Las reglas de ruta SHALL alcanzar también a los comandos de shell (que tocan ficheros sin
declarar `file_path`), y las reglas de contenido SHALL evaluarse solo sobre lo que se escribe.

#### Scenario: Ruta protegida vía shell (SC-sentinel-guard-15)

- **WHEN** el agente ejecuta `sed -i ... CHANGELOG.md` o `cat .env.production`
- **THEN** el hook deniega igual que si usara Edit

#### Scenario: Reparar un test no se bloquea (SC-sentinel-guard-16)

- **WHEN** el agente edita un test para **quitar** un `.skip(` existente
- **THEN** la acción se permite (solo se vigila lo que se escribe, no lo que se elimina)

### Requirement: Tier-awareness

Las reglas marcadas `requires_sdd` SHALL aplicarse solo cuando la política declara `sdd: true`.

#### Scenario: Tier 0 — spec-guard inactivo (SC-sentinel-guard-10)

- **WHEN** `tiers.sdd: false` y el agente edita `src/**` sin cambio OpenSpec activo
- **THEN** la regla `spec-guard` no aplica (otras reglas siguen aplicando)

### Requirement: Hooks auxiliares

`session-start` SHALL inyectar al inicio de sesión la rama actual y el cambio OpenSpec activo, y
SHALL avisar si el repo tiene la Esclusa pero en este clon no está activa ni encadenada (los git
hooks no viajan con el clon); `post-edit` SHALL formatear cada fichero editado con el comando
`format` del adaptador de stack, degradando en silencio si el entorno no está listo.

#### Scenario: Contexto al arrancar (SC-sentinel-guard-11)

- **WHEN** arranca una sesión de agente en el repo
- **THEN** el agente recibe rama actual + cambio activo (o "entre fases") sin pedirlo

#### Scenario: Autoformato con entorno caído (SC-sentinel-guard-12)

- **WHEN** `post-edit` corre y el comando `format` del adaptador no está disponible
- **THEN** no falla ni bloquea: degrada en silencio y la edición queda intacta

#### Scenario: La Esclusa inactiva en el clon se avisa (SC-sentinel-guard-22)

- **WHEN** arranca una sesión en un repo con `sentinel/githooks/` cuyo `core.hooksPath` no
  apunta a la Esclusa y cuyos hooks no la encadenan (p. ej. el clon recién hecho de un compañero)
- **THEN** el contexto de arranque avisa de que la Esclusa no está activa y da el comando que
  la activa; con la Esclusa activa (se escriba como se escriba su `core.hooksPath`, también con
  `~`) o encadenada, no avisa

### Requirement: El Centinela decide sobre lo que se toca

El Centinela SHALL proteger el enforcement por lo que la acción toca (carpetas, ruta física,
la configuración de git real del repo, la configuración de Claude Code de la persona) y no
solo por el texto de la ruta.

#### Scenario: Las carpetas protegidas no se mueven ni se borran (SC-sentinel-paths-01)

- **WHEN** el agente mueve, renombra, copia encima, enlaza, cambia los permisos o borra desde la
  shell una carpeta protegida entera (`sentinel`, `sentinel/hooks`, `sentinel/githooks`,
  `sentinel/githooks/lib`, `sentinel/adapters`, `.claude`, `.git`, `.git/hooks`, la de cada
  worktree, `.git/worktrees/<nombre>`, y `.husky`), con `mv`, `cp`, `rsync`, `ln`, `rm`, `rmdir`, `unlink`, `chmod`,
  `chown`, `git mv` o `git rm`, se escriba como `sentinel`, `sentinel/` o `./sentinel`
- **THEN** el hook deniega la acción, como la de uno de sus ficheros
- **AND** en un disco que no distingue mayúsculas (APFS por defecto en macOS, NTFS), la carpeta
  escrita con otra caja (`Sentinel/githooks`, `.GIT`, la raíz del repo en mayúsculas) es la
  misma y se deniega igual
- **AND** copiar, mover o enlazar a una carpeta (`cp x/config .git`, `cp -t .git x/config`)
  toca, dentro de ella, un fichero con el nombre de cada origen, y se decide como si el
  comando lo nombrara
- **AND** el destino es un operando: una redirección (`2>/dev/null`, `<<< x`) o el valor pegado
  a una opción (`--backup=numbered`) no lo son, una opción con su argumento detrás de los
  operandos (`--exclude x`) no lo desplaza (el destino es el último operando que es una
  carpeta), y `--target-directory` y `--no-target-directory` valen abreviadas, como las acepta
  GNU (`--target=.git`, `--t .git`, `--no-t`)
- **AND** el argumento separado de una opción que lo lleva (`--suffix docs`, `-S docs`,
  `--exclude docs`) tampoco es el destino aunque sea una carpeta; como no todos los sistemas
  tienen las mismas opciones, el destino se busca con esos argumentos y sin ellos, y cuentan los
  dos; en un grupo de letras, la que lleva argumento se queda con el resto (`-Stx` es el sufijo
  «tx», no `-t x`) (revisión de la #22)
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
  de un heredoc no esconde las líneas que le siguen, y `<<<` o el `<<` de una expresión
  aritmética no abren un heredoc
- **AND** también lo que bash ejecuta dentro de otra cosa: una sustitución entre comillas dobles
  (`"$(…)"`, `` "`…`" ``), con sus propias comillas y anidada, lo que sigue a `-c` en una shell
  (`bash`, `sh`, `zsh`, `dash`, `ksh`), también con opciones delante del código o con la shell
  como argumento (`sudo -u root bash -c`, `find -exec sh -c`), y los argumentos de `eval`; con
  más de 8 niveles de código anidado, el hook no sabe qué se ejecuta y bloquea, y la llave de
  esa acción lo salva
- **AND** una sustitución entre comillas cierra donde la cierran bash 5 y zsh, que saltan
  `$'…'`, los acentos, `${…}`, los comentarios y el cuerpo de los heredocs; si bash 3.2, que
  cuenta paréntesis, la cierra en otro sitio, el comando se lee también así, y lo que va
  detrás de cualquiera de los dos cierres se lee en su sitio. Si bash 5 no se sabe dónde la
  cierra (un `case`, una llave suelta en `${…}`, un salto de línea escapado, una aritmética
  que no cierra con `))`, unas comillas sin cerrar), el hook no sabe qué se ejecuta y bloquea
- **AND** en el cuerpo de un heredoc con el delimitador sin comillas, que bash expande, las
  comillas son texto: una sustitución cuenta aunque vaya entre comillas simples o detrás de un
  apóstrofo (`cat <<E` y `it's $(rm -rf sentinel)`) (panel corto, V4)
- **AND** el mensaje de `git commit|tag|notes|merge` o de `gh pr|issue|release` en un heredoc
  con el delimitador entre comillas (`'EOF'`, `"EOF"`, `\EOF`) que solo lee `cat`
  (`git commit -m "$(cat <<'EOF' … EOF)"`) es texto y no cuenta, aunque nombre un verbo y una
  carpeta protegida; siguen contando lo que ejecuta la salida (`bash -c`, `eval`, el programa,
  una tubería a `sh`), otro programa en la línea que abre el heredoc, lo que sigue a la línea
  que lo cierra y lo que viene después de redefinir `cat` (una función, `alias`, `hash`,
  `PATH`, o lo que ejecuta código en la shell actual: `eval`, `source`, `.`, `trap`, `mapfile`)
  (panel corto, P1; revisión de la #24)
- **AND** lo que busca un lector entre comillas (el patrón de `grep` o de `git log`/`git grep`)
  y el valor de una asignación no hacen de programa: buscar un verbo en una carpeta protegida
  (`grep -rn "chmod" sentinel/hooks`) es leerla; los argumentos de cualquier otro programa
  cuentan como sin comillas (`find -exec 'rm'`, el refspec `'+main:main'` de `git push`)
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
- **AND** buscar lo que vigila `no-hook-disabling` (`grep -rni core.hookspath docs`, `git log
  -Score.hookspath`) también es leer: esa regla lo declara, y cambiarlo
  (`git config core.hookspath …`) sigue bloqueado

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

### Requirement: Las ramas y los gates no se saltan con otra grafía

Las reglas que protegen las ramas y los gates de la Esclusa SHALL reconocer el comando como lo
ejecuta git, con sus opciones globales y lo que vaya delante.

#### Scenario: El commit y el salto de los hooks, se escriban como se escriban (SC-sentinel-paths-11)

- **WHEN** el agente intenta `git commit` (o `merge`, `cherry-pick`, `rebase`, `revert`, `am`,
  `apply`) en una rama protegida detrás de opciones globales de git con su argumento
  (`git -C . commit`, `git -c user.name=x commit`, `git --git-dir .git commit`), de un prefijo
  de ejecución (`env`, `command`, `nice -n 5`, `timeout 60`) o de una asignación
  (`X=1 git commit`)
- **THEN** el hook deniega por `protected-branches`, como con `git commit`; en una rama feature
  pasa
- **AND** saltarse los hooks se deniega también con `-n`, la forma corta de `--no-verify` en
  `git commit`, sola o en un grupo de opciones (`-nm`, `-anm`), y con las abreviaturas que
  acepta git (`--no-veri`, `--no-verif`); `-n` dentro del mensaje o tras una opción que lleva
  valor (`-mno` es el mensaje «no», `-uno` deja fuera los no seguidos) no lo es
- **AND** las reglas del comando ven cada tramo también desde su programa: sin lo que va delante
  (prefijos de ejecución, asignaciones, redirecciones) ni las opciones globales de git con su
  argumento

