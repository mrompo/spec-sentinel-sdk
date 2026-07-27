# sentinel/ci — Capa 4 (fase 3: `ci-gate`)

Template de gate de PR — **GitHub Actions primero** (A y B lo usan); GitLab CI como segundo
template. Jobs del gate (todos bloquean el merge):

1. `commitlint` (config compartida con el commit-msg local)
2. `gitleaks`
3. `quality` — `format --check` + `lint` + `static` del adaptador de stack (feature-detection:
   degrada con aviso en repos incompletos, patrón duoclaude)
4. `tests` — `tests` del adaptador + cobertura mínima
5. `boundaries` — fronteras de arquitectura (dependency-cruiser en Node; suite `arch()` en PHP)
6. `spec-coverage` — matriz escenario↔test del delta (Tier 1; CLI standalone de fase 3)
7. `verify` — validación contra la spec (Tier 1)
8. `data-review` — trigger determinista: si el diff toca `database/**` exige aprobación del
   checkpoint db-engineer
9. `mutation` *(opt-in)*

Reglas: CI usa entorno nativo, no el contenedor de desarrollo (decisión D-de-duoclaude,
documentada); la suite completa de regresión post-merge del carril hotfix vive aquí también
(no bloqueante + propuesta de revert).
