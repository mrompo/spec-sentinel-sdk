# sentinel/githooks — El puesto Esclusa (fase 2: `git-gates`)

Git hooks que actúan **sobre el resultado** (el commit, el push), no sobre la intención: da
igual si lo intenta un agente, una persona o un script. Se instalan apuntando el `hooksPath` de
git a este directorio (lo hará la skill `setup`).

La Esclusa se cierra **en dos tiempos** (decisión 1 de `git-gates`):

| Tiempo | Hook | Ejecuta | Rechaza si |
|---|---|---|---|
| **Al commitear** | `commit-msg` | Conventional Commits en **bash puro** (sin Node), el mismo criterio que commitlint. Exentos por prefijo exacto: `Merge …` y `chore(release): …` | El asunto no cumple el patrón |
| | `pre-commit` | Sobre los ficheros **en staging**: base de patrones de secretos (siempre) + gitleaks (si está) → `env-ready` → `format-check` → `lint` del adaptador de stack | Secretos, entorno roto, formato o lint en rojo |
| **Al publicar** | `pre-push` | `tests` del adaptador + rama protegida + `openspec validate --strict` (nivel Método) | Tests en rojo, push a rama protegida o spec inválida |

Los tests **no** corren al commitear: pasarlos en cada commit es lento y empuja a saltárselos.

## skip-vs-fail

| Situación | Qué hace | Ejemplo |
|---|---|---|
| Herramienta no instalada | **Skip con aviso** visible, y sigue con lo demás | gitleaks ausente; un comando del adaptador que da exit 127 |
| Sin adaptador de stack | **Skip con aviso** de lo que se omite | Repo recién clonado sin `sentinel/adapters/stack.yaml` |
| Entorno mal configurado | **Fallo duro** con la instrucción de arreglo (`env-fix`) | `env-ready` falla porque el contenedor está parado |

Nunca pasa sin comprobaciones en silencio.

## Secretos: por qué hay una base de patrones además de gitleaks

gitleaks no suele estar instalado (tampoco en el CI de este repo). Si la Esclusa dependiera
solo de él, en la mayoría de máquinas no detectaría nada. La base de patrones es pequeña y
concreta, para no dar falsos positivos: claves de acceso de AWS, cabeceras de clave privada,
tokens de GitHub (`ghp_`, `gho_`…) y de Slack (`xox?-`). Se evalúa el contenido **stageado**, no
el del árbol de trabajo, y el mensaje señala fichero y línea sin mostrar el secreto.

## Banco

Cada hook tiene sus casos en [`fixture/githooks/cases/`](../../fixture/githooks/cases), que
hacen commits y pushes reales en un repo desechable, aislado del config de git del usuario.
Si existe un hook sin casos, `fixture/verify.sh` falla.
