# sentinel/adapters — Adaptadores enchufables

El core no depende de ningún servicio externo; cada adaptador define una interfaz mínima y
sus implementaciones. Toda skill que use un adaptador declara fallback CLI/manual.

## stack (`sentinel.yaml` del consumidor)

Interfaz: `format` · `lint` · `static` · `tests` · `domain-lint` (opcional) + `env-ready`
(detección de entorno listo, p. ej. contenedor corriendo). Hooks, githooks y CI consumen estos
comandos sin conocer el stack.

Perfiles completos (adaptador + guidelines versionadas + MCP de introspección + docs
versionadas + skills de paquete — patrón **Laravel Boost**, plan §3):
- `laravel/` — sobre Boost (`boost:install`; MCP solo contra entorno local, regla `isolation`)
- `node/` — v1 solo adaptador de comandos (emular Boost queda descoped)

## tracker

Interfaz: `get-ticket` · `link-pr` · `transition` · `comment`. Implementaciones: Jira
(config declarativa por proyecto: cloudId, tipos de issue, ids de transición — patrón B),
después Linear o GitHub Issues (decisión en fase 6).

## forge

CLI antes que MCP: `gh` (primero) / `glab`. Usado por `pull-request`, `release`, `hotfix`
(comparación de ramas para el gate de back-merge).
