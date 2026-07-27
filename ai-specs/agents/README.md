# ai-specs/agents — Contrato de subagentes

Aquí viven las definiciones de los 7 subagentes del SDK (plan §4). **Esta carpeta define el
contrato; los agentes se implementan en la fase 6 (`team`).**

## Formato de cada agente

Un directorio por agente:

```
<nombre-agente>/
├── AGENT.md        # Definición: frontmatter + rol + reglas + contrato de salida
└── context.yaml    # Manifiesto de contexto (obligatorio)
```

### AGENT.md

- Frontmatter: `name`, `description` (con trigger de delegación proactiva si aplica),
  `tools` (mínimos necesarios), `write_scope` (patrones de ruta donde puede escribir; vacío =
  solo-lectura).
- Cuerpo: rol, reglas duras, y **contrato de salida** explícito (p. ej. el del revisor:
  *"lista de violaciones con `fichero:línea` y sugerencia, o OK"*).

### context.yaml — manifiesto de contexto

Lista **declarativa y exhaustiva** de lo que el agente carga (rutas de docs, specs, adapters).
Regla del plan §4: el contexto acotado deja de ser una intención — `doctor` (fase 4) valida
que toda referencia exista. Nada de "el agente ya lo encontrará": si no está en el manifiesto,
no forma parte de su contexto.

## Reglas transversales (plan §4)

1. Quien implementa tiene escritura acotada; quien revisa es solo-lectura; quien
   orquesta/diseña no escribe código.
2. Una persona no invoca a otra persona — el orquestador compone.
3. Revisores con contexto limpio: nunca ven el razonamiento del implementador.
4. Perfiles bajo demanda (db-engineer, futuros) declaran su **trigger determinista**.
