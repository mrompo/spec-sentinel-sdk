# sentinel/hooks — Capa 2 (fase 1: `sentinel-guard`)

Tres hooks, tres arquetipos (no habrá más scripts — las reglas nuevas van a `../policy.yaml`):

| Hook | Evento | Arquetipo | Qué hace |
|---|---|---|---|
| `sentinel-guard.sh` | PreToolUse (Bash, Edit\|Write, Read) | *block* | Evalúa `policy.yaml` regla a regla; deniega con exit 2 + motivo; registra overrides de break-glass |
| `session-start.sh` | SessionStart | *inject* | Inyecta rama actual + cambios OpenSpec activos + decisiones recientes |
| `post-edit.sh` | PostToolUse (Edit\|Write) | *auto-fix* | Formatea el fichero editado con el comando `format` del adaptador de stack; degradación silenciosa si el entorno no está listo |

Contrato técnico (heredado de duoclaude, portable tal cual): stdin = JSON del tool call,
parseo barato sin `jq`; **exit 2 + stderr = denegado con motivo**; exit 0 = pasa.
Los hooks se cablean en `.claude/settings.json` (y equivalentes por herramienta) durante la
instalación (`setup`, fase 2).

Tests: cada regla de `policy.yaml` tiene su caso en el fixture — toda regla dura tiene un test
que la falsifica, también las del framework.
