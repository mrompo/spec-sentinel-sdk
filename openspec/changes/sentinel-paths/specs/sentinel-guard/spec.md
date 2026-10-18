# sentinel-guard — Delta spec (sentinel-paths)

## ADDED Requirements

### Requirement: El Centinela decide sobre lo que se toca

El Centinela SHALL proteger el enforcement por lo que la acción toca (carpetas, ruta física,
la configuración de git real del repo) y no solo por el texto de la ruta, y SHALL no bloquear
las acciones legítimas que solo se parecen a una protegida.

#### Scenario: Las carpetas protegidas no se mueven ni se borran (SC-sentinel-paths-01)

- **WHEN** el agente mueve, renombra o borra desde la shell `sentinel/`, `sentinel/hooks`,
  `sentinel/githooks` o `.claude/`
- **THEN** el hook deniega la acción, como la de uno de sus ficheros

#### Scenario: Un enlace no abre un fichero protegido (SC-sentinel-paths-02)

- **WHEN** el agente escribe a través de un enlace cuya ruta física es un fichero protegido (en
  `.claude/`, `sentinel/` o la configuración de git)
- **THEN** el hook deniega la acción, como por la ruta directa

#### Scenario: La configuración de git es la real del repo (SC-sentinel-paths-03)

- **WHEN** el agente edita la configuración de git del repo en una disposición que no la llama
  `.git` (p. ej. un repo bare con worktrees), o cambia `core.hooksPath` desde un comando sin
  nombrarlo (borrando la sección `core` o con un `include.path`)
- **THEN** el hook deniega la acción

#### Scenario: Lo que solo se parece no se bloquea (SC-sentinel-paths-04)

- **WHEN** el agente edita un fichero que solo se parece a la configuración de git (p. ej.
  `docs/.gitconfig.example` o un repo de dotfiles) o lee un fichero protegido
- **THEN** el hook deja pasar la acción

#### Scenario: La llave autoriza la acción prevista (SC-sentinel-paths-05)

- **WHEN** hay una llave y otra acción bloqueada (de cualquier agente de la sesión) llega antes
  que la que la persona autorizó
- **THEN** esa otra acción no gasta la llave
