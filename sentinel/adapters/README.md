# sentinel/adapters — Adaptadores enchufables

El core no depende de ningún servicio externo; cada adaptador define una interfaz mínima y
sus implementaciones. Toda skill que use un adaptador declara fallback CLI/manual.

## stack (`sentinel/adapters/stack.yaml` del consumidor)

Interfaz: `format` · `format-check` · `lint` · `static` · `tests` · `domain-lint` (opcional) +
`env-ready` (detección de entorno listo, p. ej. contenedor corriendo). El Centinela, la Esclusa y
la Aduana consumen estos comandos sin conocer el stack, a través de [`stack.sh`](stack.sh).

```yaml
# sentinel/adapters/stack.yaml — plano, una clave por línea
tests: npm test
lint: npm run -s lint --          # recibe los ficheros en staging
format-check: npx prettier --check
env-ready: docker compose ps --status running --quiet app | grep -q .
```

- **Sin fichero, sin comandos**: quien lo consume omite con aviso, nunca falla ni adivina.
- **`stack_detect <dir>`** propone un `stack.yaml` para Node (según los scripts de
  `package.json`) o Laravel (`artisan` + Pint/PHPStan si están). Solo imprime: lo aplica
  `setup`, y la persona lo revisa.
- *(Antes se llamaba `sentinel.yaml` en la raíz; el nombre era ambiguo, hallazgo #27 del panel.
  El Centinela lo leerá del sitio nuevo en el slice 3b de `git-gates`.)*

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
