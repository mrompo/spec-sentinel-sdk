# Revisión adversarial, ronda 5 — `git-gates` PR 3/3 (instalación)

**Fecha**: 2026-10-18 · **Rama**: `feature/git-gates-install` (contenido de `189a2c8`, el U6 de
la ronda 5) · Mismo método que las rondas anteriores: tres lentes nuevas con contexto limpio,
`counter-review` cruzado y veredicto con [`../synthesis.sh`](../synthesis.sh). Fuera de alcance,
por decisión de la persona: la convivencia con otros gestores de hooks
([`hook-coexistence`](../../../../hook-coexistence/proposal.md)), la versión del SDK
([`sdk-version`](../../../../sdk-version/proposal.md)), los límites «regex evadibles» y «jq
manipulado», el resto de la tabla de límites y la deuda registrada en `STATUS.md`.

## La ronda 4

Resueltos 19 de 20, según las tres lentes. La raíz de la ronda 4 (el lector JSON propio) se cierra
al exigir jq: la gramática, las claves repetidas, los escapes, lo que jq acepta y JSON no, la
fusión fuera de `.hooks` y la configuración que apaga los hooks se comprueban como los carga
Claude Code. El Pragmatist lo contrastó con jq 1.6 a 1.8.2 y con los awk de BSD, mawk, gawk y
busybox, en macOS, Debian, Ubuntu y Alpine. Sigue abierto **A4-5**: los casos «escrita con un
escape» de `sc-14` no llevan escape (la herramienta con la que se escribió el fichero decodificó
el `\u`), así que el banco no lo falsifica.

## Veredicto: `HOLD`

Los 27 hallazgos están validados (25 por las tres lentes; V5-3 y V5-4, por dos). Agrupados por
defecto:

| # | Defecto | Hallazgos | Severidad |
|---|---|---|---|
| 1 | jq carga `~/.jq` en cada programa. El agente puede escribir ese fichero y, con el jq legítimo del sistema, `setup` quita el cableado y dice «✓ Nivel Guardia instalado» (exit 0). El Pragmatist lo ve dentro del límite «jq manipulado»; Auditor y Adversary, no, porque el binario es el legítimo | V5-3 | 🛑 bloqueante |
| 2 | Regresión de la ronda 5: un jq del repo que es un enlace a un binario de fuera se usa, porque solo se mira dónde acaba el enlace | A5-1 | grave |
| 3 | Las carpetas protegidas se mueven o borran enteras (`mv` o `git rm -r` de `sentinel/hooks`, `sentinel/githooks`, `.claude`) sin bloqueo ni aprobación, y el Centinela o la Esclusa quedan sin efecto. Preexistente (fase 1, PR 2/3) | V5-1 | grave |
| 4 | El guard compara el texto de la ruta y no el fichero físico: a través de un enlace a `.claude`, `sentinel` o `.git` se editan los ficheros protegidos. Preexistente. Misma raíz que la disposición «repo bare + worktrees» (A5-3) | V5-2 | grave |
| 5 | Sin `.gitattributes`, un clon con finales de línea CRLF (Git for Windows por defecto) rompe `setup`, el Centinela (lo deniega todo) y la Esclusa (rechaza todo). Falla cerrado; la política de soporte de Windows está abierta (plan §11) | P5-1 | grave |
| 6 | Menores y retoques: bytes de control o NUL que jq acepta (A5-2, V5-8); otras vías hacia `core.hooksPath` (`--remove-section`, `include.path`) y la disposición bare (V5-4, A5-3); falsos positivos de la regla nueva de la configuración de git (P5-6); `CLAUDE_CONFIG_DIR` en otra ruta (V5-7); `BASH_ENV` en `env` (V5-6); configuración gestionada (A5-5 = P5-8); `sdd: true` sin aviso (P5-2); el bucle de la forma inesperada en `hooks` (P5-3); la excepción de `.claude/` (P5-4); `settings.local.json` ya versionado o con una negación (P5-5 = A5-7, V5-5); el `jq.exe` con CRLF (P5-7); `SENTINEL_SETUP_JQ` dentro del repo (A5-4); el «dónde» del léxico (A5-6); el banco del escape (A5-prev-A4-5 = P5-prev-A4-5); la guía (P5-9, P5-10) | el resto | menores y retoques |

Las lentes coinciden en que lo propio de la ronda 5 aguanta: el bloqueante y la regresión están
en cómo se elige y se ejecuta jq, no en cómo se valida el JSON. Los defectos 3 y 4 son del
Centinela, no del instalador, y vienen de antes de esta PR.

## Disposición (gate **Resolución** 👤)

Decidida por una persona el 2026-10-18:

- **En esta PR**, lo del instalador (ronda 6 de `apply`, slices W1-W7 de `tasks.md`):
  - el defecto 1: jq se ejecuta con un `HOME` aislado y `~/.jq` queda protegido;
  - el defecto 2: un jq del repo no se usa, se llegue a él como se llegue;
  - el defecto 5: `.gitattributes` en el SDK y en el consumidor, con su caso en el banco y una
    nota en la guía para Git for Windows (Windows nativo no se declara soportado);
  - los menores baratos del instalador: bytes NUL y de control (A5-2, V5-8), `SENTINEL_SETUP_JQ`
    dentro del repo (A5-4), el «dónde» del léxico (A5-6), el bucle de la forma de `hooks`
    (P5-3), la excepción de `.claude/` (P5-4), `settings.local.json` versionado o negado (P5-5
    = A5-7, V5-5), decidir con `jq -e` (P5-7), `BASH_ENV` y compañía en `env` (V5-6), la
    configuración gestionada (A5-5 = P5-8), el aviso de `sdd: true` (P5-2), el banco del escape
    (A5-prev-A4-5 = P5-prev-A4-5) y los textos de la guía (P5-9, P5-10).
- **Cambio propio** para el Centinela,
  [`sentinel-paths`](../../../../sentinel-paths/proposal.md): carpetas protegidas (V5-1), rutas
  físicas y enlaces (V5-2), la disposición «repo bare + worktrees» (A5-3), otras vías hacia
  `core.hooksPath` (V5-4), los falsos positivos de la configuración de git (P5-6) y
  `CLAUDE_CONFIG_DIR` en otra ruta (V5-7). Recoge también que la llave la gaste la primera
  acción bloqueada de cualquier agente de la sesión, observado durante este panel.
