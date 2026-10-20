# Revisión adversarial, ronda 4 — `git-gates` PR 3/3 (instalación)

**Fecha**: 2026-10-17 · **Rama**: `feature/git-gates-install` (contenido de `be8ec28`, el T6 de la
ronda 4) · Mismo método que las rondas anteriores: tres lentes nuevas con contexto limpio,
`counter-review` cruzado y veredicto con [`../synthesis.sh`](../synthesis.sh). Fuera de alcance,
por decisión de la persona: la convivencia con otros gestores de hooks
([`hook-coexistence`](../../../../hook-coexistence/proposal.md)), la versión del SDK
([`sdk-version`](../../../../sdk-version/proposal.md)), el límite «regex evadibles» y la deuda
registrada en `STATUS.md`.

## La ronda 3

Resueltos: `disableAllHooks: true` en los ficheros del proyecto (A3-1), el enlace de la skill
(P3-2 = A3-prev-A2-5), `AGENTS.md` en los consumidores (P3-3), la spec alineada con el límite
(A3-prev-V2-6) y los textos (V3-1, P3-6, P3-7, P3-9). Sigue abierto, más estrecho: la
comprobación del cableado (P3-1 = A3-prev-A2-prevA4). Las claves repetidas, los escapes y la
basura tras el objeto ya se rechazan, pero no la gramática.

## Veredicto: `HOLD`

Los 20 hallazgos están validados por las tres lentes. Agrupados por defecto:

| # | Defecto | Hallazgos | Severidad |
|---|---|---|---|
| 1 | El lector del cableado no valida la gramática JSON. Sin jq, el fragmento pegado a mano con una coma de más o de menos, un comentario o un literal mal escrito da «✓ ya cableado» (exit 0) y retira el fragmento. Con un jq de fuera del repo, el fichero escrito puede no ser JSON. En los dos casos Claude Code descarta el fichero entero, Centinela incluido | A4-prev-P3-1 = P4-1 = V4-prev-A3-prev-A2-prevA4, V4-prev-P3-1 | 🛑 bloqueante |
| 2 | La comprobación de la fusión solo mira el cableado y `disableAllHooks`; lo que cambie fuera de `.hooks` (un `env` con variables `SENTINEL_*`, que llegan al guard) pasa sin ver | V4-1 | grave |
| 3 | `git add sentinel .claude .gitignore` mete `.claude/settings.local.json` (permisos y entorno personales) en el commit del equipo cuando git no lee el ignore global donde Claude Code lo excluye | A4-6 | grave |
| 4 | Cuando el fichero no es JSON estricto, el pendiente culpa a un «cableado antiguo» y pide sustituir entradas que ya son las actuales: seguirlo lleva a un bucle en exit 3 | P4-2 = A4-4 | grave |
| 5 | `.git/config` no está protegido: Edit o Write pueden cambiar el `hooksPath` aunque el comando `git config` esté bloqueado. Preexistente (PR 2/3) | V4-4 | grave |
| 6 | Con la sesión abierta en un subdirectorio (un paquete de un monorepo), Claude Code no carga el `.claude/settings.json` de la raíz y nada lo dice. Preexistente (fase 1) | V4-5 | grave |
| 7 | Menores y retoques: `disableAllHooks` en un fichero no estricto o en la configuración de usuario; el banco no falsifica el escape en las claves; el nombre genérico «setup» del enlace de la skill (hueco con otro nombre, falso positivo con una skill propia, `ln -s` de la guía frágil); la asimetría con jq ante `hooks` repetida; JSON válido fuera del esquema de Claude Code; la lista fija de eventos | A4-2 = V4-2, A4-3 = P4-4, A4-5, A4-7, P4-5, P4-3, V4-3, P4-6 | menores y retoques |

Las tres lentes coinciden en la raíz del defecto 1: un lector de JSON escrito a mano en awk
diverge de `JSON.parse` en cada ronda. Los defectos 4 y parte del 7 (A4-2, A4-5, P4-3, P4-6)
salen de la misma raíz.

## Disposición (gate **Resolución** 👤)

Decidida por una persona el 2026-10-18:

- **Raíz del defecto 1**: `setup` exige jq, como ya exige gitleaks. Lee, fusiona y comprueba con
  jq, que resuelve las claves repetidas y los escapes igual que `JSON.parse`; desaparecen el
  lector en awk y el pegado a mano sin jq. Un jq manipulado fuera del repo pasa a la tabla de
  límites, junto a un `git` o un `bash` manipulados.
- **En esta PR** (ronda 5 de `apply`, slices U1-U7 de `tasks.md`): los defectos 1 a 6 y los
  menores baratos: `disableAllHooks` en la configuración de usuario y con un valor que no sea
  booleano, la comprobación con `/hooks` en una sesión nueva y un nombre propio para el enlace
  de la skill, con un `ln -s` que no falle ni se anide. Con jq se resuelven también A4-2 = V4-2,
  A4-5, P4-3 y P4-6.
- **Deuda registrada**: el enlace de la skill con un nombre distinto del de la guía (resto de
  P4-5) y el JSON válido fuera del esquema de Claude Code más allá de `disableAllHooks` (resto
  de V4-3, límite documentado).
