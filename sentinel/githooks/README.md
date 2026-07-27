# sentinel/githooks — Capa 3 (fase 2: `git-gates`)

Templates instalables con `git config core.hooksPath` (vía skill `setup`):

| Hook | Ejecuta | Falla si |
|---|---|---|
| `commit-msg` | Conventional commits en **bash puro** (regex, sin Node) — mismo criterio que commitlint; bypass para `Merge` y `chore(release)` | El asunto no cumple el patrón |
| `pre-commit` | gitleaks sobre staged (si está instalado) + `format --check` + `lint` del adaptador de stack, solo sobre staged | Secretos, estilo o estático |
| `pre-push` | `tests` del adaptador + `openspec validate --strict` (solo Tier 1) | Tests en rojo o spec inválida |

Patrón obligatorio **skip-vs-fail** (duoclaude): herramienta no instalada → skip con aviso y
enlace al README; entorno mal configurado (p. ej. contenedor parado) → **fallo duro** con la
instrucción exacta de arreglo. Nunca pasar sin checks en silencio.
