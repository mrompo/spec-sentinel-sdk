# sentinel/hooks — El puesto Centinela (fase 1: `sentinel-guard`)

Tres hooks, tres arquetipos (no habrá más scripts — las reglas nuevas van a la política:
`../policy.default.yaml` las del SDK, `../policy.yaml` las del proyecto):

| Hook | Evento | Arquetipo | Qué hace |
|---|---|---|---|
| `sentinel-guard.sh` | PreToolUse (Bash, Edit\|Write, Read) | *block* | Evalúa las dos políticas, `policy.default.yaml` y `policy.yaml` (en cada una decide la primera regla que matchea; entre las dos, la más estricta); deniega con exit 2 + motivo; registra overrides de break-glass |
| `session-start.sh` | SessionStart | *inject* | Inyecta rama actual + cambios OpenSpec activos + decisiones recientes; avisa si la Esclusa no está activa en el clon |
| `post-edit.sh` | PostToolUse (Edit\|Write) | *auto-fix* | Formatea el fichero editado con el comando `format` del adaptador de stack; degradación silenciosa si el entorno no está listo |

Contrato técnico (heredado de duoclaude, portable tal cual): stdin = JSON del tool call,
parseo barato sin `jq`; **exit 2 + stderr = denegado con motivo**; exit 0 = pasa.
Los hooks se cablean en `.claude/settings.json` (y equivalentes por herramienta) al instalar
con `setup` (`ai-specs/skills/setup/`).

Tests: cada regla de la política del SDK tiene su caso en el fixture — toda regla dura tiene un
test que la falsifica, también las del framework.
