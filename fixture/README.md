# fixture/ — Banco de pruebas del framework

Toda regla dura del SDK tiene aquí un test que la falsifica — **también las del propio
framework**. Cada fase del roadmap añade sus checks; el workflow
`.github/workflows/fixture.yml` los ejecuta en cada push/PR.

| Fase | Qué verifica aquí |
|---|---|
| 0 (esta) | `verify.sh`: estructura §3 completa + symlinks multi-copilot resolubles (SC-sdk-method-03/04) + cambio OpenSpec activo bien formado |
| 1 | Cada regla de `policy.yaml` bloqueada/permitida contra `demo-app/` + override auditado |
| 2 | `setup` instala Tier 0 en `demo-app/` con un comando; skip-vs-fail de githooks |
| 3 | Un `Scenario` sin test rompe el gate (spec-coverage); PR sin gates no mergea |
| 4+ | Ciclo SDD end-to-end sobre `demo-app/`; doctor detecta refs colgantes sembradas |

`demo-app/` es el mini-repo consumidor donde se instala y ejercita cada tier.

Decisión (pregunta abierta de tasks.md): el fixture vive **dentro** del repo hasta que el
instalador exija probar instalación remota.
