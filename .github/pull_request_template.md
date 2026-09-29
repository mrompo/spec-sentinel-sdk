<!--
Formato de PR de Spec Sentinel (expediente openspec pr-format).
Título: Conventional Commits — tipo(ámbito): descripción
Reglas: no borres ninguna sección. Si no aplica, déjala con «N/A — <motivo>».
Los comentarios como este no se ven en la PR publicada: puedes dejarlos.
-->

## 1. Expediente

<!-- Enlace al cambio OpenSpec (openspec/changes/<n>/), fase del roadmap y slice n/m.
     Exentas: chore(release) y back-merges → «N/A — release» / «N/A — back-merge». -->

- **Cambio**:
- **Fase del roadmap**:
- **Slice**:

## 2. Posición en el Loop

<!-- Qué gates están cerrados y cuál cierra esta PR (normalmente Aduana).
     Un gate que aún no existe en el framework va como «N/A — <motivo>». -->

| Gate | Estado |
|---|---|
| Intención 👤 | |
| Claridad ⚙️👤 | |
| Diseño 👤 | |
| Plan ⚙️👤 | |
| Esclusa ⚙️ | |
| Verde ⚙️ | |
| Veredicto ⚙️ | |
| **Aduana** ⚙️👤 | ⏳ esta PR |

## 3. Qué cambia y por qué

<!-- De 3 a 6 puntos, escritos para una persona que no ha seguido el trabajo. -->

-

## 4. Escenarios

<!-- Cada SC-* del delta spec → qué test o check lo cubre → estado.
     Sin test todavía: dilo y explica por qué. Sin delta: «N/A — <motivo>». -->

| Escenario | Cubierto por | Estado |
|---|---|---|
| | | |

## 5. Qué NO cambia

<!-- Comportamiento, contratos o ids que se mantienen.
     ⚠️ Avisa aquí si la PR toca el propio enforcement de Shield (hooks, política, cableado). -->

-

## 6. Verificación

<!-- Qué se ha ejecutado y con qué resultado. -->

| Qué | Resultado |
|---|---|
| `bash fixture/verify.sh` | |
| `openspec validate --all --strict` | |
| CI | |

## 7. Riesgos y vuelta atrás

<!-- Qué puede salir mal y cómo se revierte. -->

- **Riesgo**:
- **Vuelta atrás**:

## 8. Excepciones y deuda

<!-- Usos de la llave (líneas añadidas a sentinel/overrides.log) y deuda registrada en STATUS.md.
     «ninguna» es válido, pero solo si el diff no añade líneas a la bitácora. -->

- **Llave**:
- **Deuda**:

## 9. Procedencia

<!-- Qué hizo un agente (y con qué modelo) y qué una persona; quién revisó.
     Nunca es «N/A»: si no hubo agente, escribe «sin agente». -->

- **Agente**:
- **Persona**:
- **Revisión**:

## 10. Foco de la revisión

<!-- De 1 a 3 puntos: dónde debe mirar el revisor. -->

1.
