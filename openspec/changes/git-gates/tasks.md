# Tasks — git-gates

**Objetivo**: Tier 0 instalable en cualquier repo con un comando, con capa 3 real.
**Ritmo**: un slice = caso del fixture en rojo → implementación mínima → verde → commit atómico.

## Checklist

- [ ] 1. Runner de git hooks en el fixture: workspace con `git init` + commits reales
       (aprovecha `fixture/hooks/harness.sh`); se engancha a `verify.sh`
- [ ] 2. `commit-msg` en bash puro: Conventional Commits + bypass merges/release
       (SC-git-gates-01, 02)
- [ ] 3. `sentinel/adapters/stack.yaml` + autodetección Node/Laravel + renombrado en `post-edit`
       (SC-git-gates-07)
- [ ] 4. `pre-commit`: gitleaks + format --check + lint sobre staged, con **skip-vs-fail**
       (SC-03, 06)
- [ ] 5. `pre-push`: tests + rama protegida (cierra el TOCTOU) + openspec validate opcional
       (SC-04, 05)
- [ ] 6. Separación `policy.default.yaml` / `policy.yaml` del consumidor (SC-09)
- [ ] 7. Skill `setup`: instalación de un comando (copia, `core.hooksPath`, fusión de
       `.claude/settings.json` con backup, detección de stack) (SC-08)
- [ ] 8. Caso de instalación end-to-end en `demo-app/`: tras `setup`, los gates bloquean
       (SC-10) — DoD de la fase
- [ ] 9. Auto-instalación en este repo (`core.hooksPath` apuntando a `sentinel/githooks`)
- [ ] 10. STATUS.md + sección «Instalar en tu proyecto» de docs/guia-uso.md → code-review
       adversarial → archive

## Notas de diseño (design gate)

- Los git hooks **no dependen** del adaptador para funcionar: si no hay `stack.yaml`, hacen
  skip con aviso (un repo recién clonado no debe romperse).
- `pre-push` es el sitio correcto para la rama protegida: ahí el commit ya existe y no hay
  TOCTOU posible (hallazgo del panel adversarial en fase 1).
- El instalador **nunca pisa** configuración del consumidor: backup + fusión conservadora, y
  ante la duda, instrucción manual explícita.
