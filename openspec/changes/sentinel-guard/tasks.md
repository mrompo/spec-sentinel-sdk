# Tasks — sentinel-guard

**Objetivo**: capa 2 real según el delta spec (un slice = tests del fixture primero, en rojo →
implementación mínima → verde → commit atómico).

## Checklist

- [x] 1. Runner de hooks en el fixture: simula tool calls (JSON → hook) sobre `demo-app/`
       copiada a temporal + `git init` (patrón acordado); se engancha a `verify.sh`
- [x] 2. Esqueleto `sentinel-guard.sh`: parse stdin + carga de política + exit codes
       (SC-sentinel-guard-01, 02)
- [ ] 3. Reglas block: ramas protegidas + ficheros gestionados (SC-03, SC-04)
- [ ] 4. protect-tests + destructivos (confirm) + aislamiento (SC-05, SC-06)
- [ ] 5. Modo warn + tier-awareness `requires_sdd` (SC-07, SC-10)
- [ ] 6. Break-glass: `SENTINEL_OVERRIDE` + `overrides.log` versionado (SC-08, SC-09)
- [ ] 7. `session-start.sh` + `post-edit.sh` (SC-11, SC-12)
- [ ] 8. Cableado `.claude/settings.json` en este repo + instalación manual en duoclaude
       (evidencia del DoD: bloqueo real observado en ambos)
- [ ] 9. STATUS.md + sección «Guardarraíles» de docs/guia-uso.md actualizados → PR →
       revisión humana → archive

## Notas de diseño (para el design gate)

- **Fail-closed**: política ilegible → bloquear con mensaje, nunca pasar en silencio.
- Orden de evaluación: primera regla que matchea decide; `id` obligatorio y único (el log de
  overrides referencia el id).
- `confirm` se materializa con el mecanismo de permisos del harness (permissionDecision ask);
  si el harness no lo soporta, degrada a block con instrucción de re-lanzar tras aprobación.
