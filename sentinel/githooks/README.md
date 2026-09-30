# sentinel/githooks — El puesto Esclusa (fase 2: `git-gates`)

Git hooks que actúan **sobre el resultado** (el commit, el push), no sobre la intención: da
igual si lo intenta un agente, una persona o un script. Se instalan apuntando el `hooksPath` de
git a este directorio (lo hará la skill `setup`).

La Esclusa se cierra **en dos tiempos** (decisión 1 de `git-gates`):

| Tiempo | Hook | Ejecuta | Rechaza si |
|---|---|---|---|
| **Al commitear** | `commit-msg` | Conventional Commits en **bash puro** (sin Node), el mismo criterio que commitlint. Exentos por prefijo exacto: `Merge …` y `chore(release): …` | El asunto no cumple el patrón |
| | `pre-commit` | Sobre los ficheros **en staging**: base de patrones de secretos + **gitleaks (obligatorio)** → `env-ready` → `format-check` → `lint` del adaptador de stack | Secretos, gitleaks ausente, entorno roto, formato o lint en rojo |
| **Al publicar** | `pre-push` | `tests` del adaptador + rama protegida + `openspec validate --strict` (nivel Método) | Tests en rojo, push a rama protegida o spec inválida |

Los tests **no** corren al commitear: pasarlos en cada commit es lento y empuja a saltárselos.

## Requisitos

| Herramienta | ¿Obligatoria? | Si falta |
|---|---|---|
| `git`, `bash` (3.2 o posterior) | Sí | — |
| **gitleaks** v8 | **Sí** (decisión 6 de `git-gates`) | **Fallo duro**: el commit se rechaza con la instrucción de instalación (SC-git-gates-10) |
| Comandos del adaptador de stack | No | Skip con aviso (SC-git-gates-06) |
| `openspec` CLI | No (nivel Método) | Skip con aviso; la Aduana (fase 3) lo hará obligatorio |

Instalar gitleaks:

| Sistema | Comando |
|---|---|
| macOS | `brew install gitleaks` |
| Linux | Binario de <https://github.com/gitleaks/gitleaks/releases>, o `go install github.com/zricethezav/gitleaks/v8@latest` |
| Windows | `scoop install gitleaks` |

Comprueba que está con `gitleaks version`. La Esclusa usa `gitleaks git --pre-commit --staged`
en v8.19 o posterior, y `gitleaks protect --staged` en las anteriores.

## skip-vs-fail

| Situación | Qué hace | Ejemplo |
|---|---|---|
| Herramienta opcional no instalada | **Skip con aviso** visible, y sigue con lo demás | Un comando del adaptador que da exit 127 |
| Sin adaptador de stack | **Skip con aviso** de lo que se omite | Repo recién clonado sin `sentinel/adapters/stack.yaml` |
| Herramienta obligatoria no instalada | **Fallo duro** con la instrucción de instalación | gitleaks ausente |
| Entorno mal configurado | **Fallo duro** con la instrucción de arreglo (`env-fix`) | `env-ready` falla porque el contenedor está parado |

Nunca pasa sin comprobaciones en silencio.

## Excepción auditada (break-glass)

Todo rechazo de la Esclusa se puede saltar **solo** con la misma excepción que el Centinela
(decisión 8 de `git-gates`, [`lib/breakglass.sh`](lib/breakglass.sh)):

| Vía | Alcance | Cómo |
|---|---|---|
| **La llave** | Un solo rechazo: se consume al aplicarse | Una persona escribe el motivo: `echo "motivo" > sentinel/.override` |
| `SENTINEL_OVERRIDE` | Toda la sesión | Una persona arranca la sesión con `SENTINEL_OVERRIDE="motivo"` |

Cada uso deja una línea en la bitácora (`sentinel/overrides.log`), con el mismo formato que el
Centinela: `fecha | esclusa:<hook> | qué se rechazaba | motivo`. Reglas:

- **Sin bitácora escribible no hay excepción**, y la llave se conserva para reintentar.
- **Un motivo vacío o solo de espacios no vale.**
- **Un rechazo, una llave**: si el mismo commit lo rechazan `pre-commit` y `commit-msg`, hacen
  falta dos.
- `git commit --no-verify` salta la Esclusa **sin rastro**: no se puede impedir porque es de git,
  pero con esta vía deja de hacer falta. Al agente se lo bloquea el Centinela, y la Aduana
  (fase 3) detectará en CI lo que entre sin pasar por la Esclusa.
- ⚠️ La llave solo es segura si el agente no puede crearla. **Hoy el Centinela aún no lo impide**:
  se corrige en la PR 2/3 de `git-gates` (slice 6b).

## Secretos: gitleaks y la base de patrones

**gitleaks es obligatorio**: un secreto que llega a la historia de git es caro de sacar (hay que
reescribirla y rotar la credencial), y exigir la herramienta cuesta menos que confiar en que
cada máquina la tenga.

Por debajo corre siempre una **base de patrones en bash**, como segunda red por si gitleaks está
mal configurado. Es pequeña y concreta, para no dar falsos positivos: claves de acceso de AWS,
cabeceras de clave privada, tokens de GitHub (`ghp_`, `gho_`…) y de Slack (`xox?-`). Las dos
evalúan el contenido **stageado**, no el del árbol de trabajo. La base de patrones señala fichero
y línea sin mostrar el secreto; gitleaks, con `--redact`, tampoco lo muestra.

## Banco

Cada hook tiene sus casos en [`fixture/githooks/cases/`](../../fixture/githooks/cases), que
hacen commits y pushes reales en un repo desechable, aislado del config de git del usuario.
El banco **no** necesita gitleaks: usa un gitleaks falso (`gl_ok` en el harness), así que los
casos prueban la lógica de la Esclusa, no la instalación de la máquina.
Si existe un hook sin casos, `fixture/verify.sh` falla.
