# ai-specs/skills — Contrato de skills

Aquí vive el catálogo de ~21 skills del SDK (plan §5). **Esta carpeta define el contrato; las
skills se implementan en las fases 4-6.** Conformes a la [Agent Skills spec](https://skills.addy.ie)
para ser interoperables con ese ecosistema.

## Anatomía obligatoria (patrón agent-skills, plan §5)

```
<nombre-skill>/
├── SKILL.md          # < 500 líneas. Punto de entrada único.
└── references/       # Opcional: checklists que se cargan bajo demanda (progressive disclosure)
```

Secciones de `SKILL.md`, en orden:

1. **Frontmatter** — `name`, `description` con triggers de activación.
2. **Overview** — propósito en 2-3 líneas.
3. **When to Use** — condiciones (y cuándo NO usarla).
4. **Process** — pasos numerados con checkpoints y salidas explícitas.
5. **Rationalizations** — tabla excusa → contraargumento (anti-atajos).
6. **Red Flags** — señales de que algo va mal.
7. **Verification** — evidencia medible exigida al terminar. *"Parece correcto" nunca basta.*

Principio rector: **process, not prose** — flujos que el agente sigue, no documentación que lee.

## Reglas

- **Fuente única**: los commands por herramienta (`/spec-intake`, …) se **generan** en la
  instalación; nunca se mantienen a mano (decisión plan §11).
- **Vendoring**: skills externas (D, grill-me…) entran vía `skills-lock.json`
  (source + sourceType + hash) — nunca copia sin procedencia.
- Toda skill nueva pasa por `writing-skills` (validación antes de publicar) y el fixture.
- Las skills que usan MCP declaran **fallback CLI/manual** (plan §8).
