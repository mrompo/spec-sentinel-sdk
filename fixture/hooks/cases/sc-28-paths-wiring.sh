#!/usr/bin/env bash
# SC-sentinel-paths-06: el cableado ejecuta el Centinela con un entorno que no sale de la sesión
#   (ni el bash ni el grep del PATH, ni BASH_ENV, SHELLOPTS, funciones exportadas o GIT_DIR), y
#   el Centinela decide como sin ese entorno.
# SC-sentinel-paths-09: si el Centinela no está, no se puede leer o termina con un código que no
#   es ni 0 ni 2, el cableado sale con 2 y dice cómo restaurarlo; en una rama sin el SDK, cómo
#   volver. Sin un git que responda en el proyecto, sale con 2 y dice por qué: que no está
#   instalado o lo que dice git (revisión de sentinel-paths, P3, P6 = A9).
# El PATH fijo incluye las carpetas donde Git for Windows, Nix y linuxbrew dejan git (P1).
# Se ejecuta el comando del cableado tal como queda en .claude/settings.json, con /bin/sh, como
# lo ejecuta Claude Code.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

# El comando del cableado del Centinela, sacado del JSON (sin jq: \" → " y \\ → \)
WIRING="$(grep -F 'sentinel/hooks/sentinel-guard.sh' "$REPO_ROOT/.claude/settings.json" | head -1 \
  | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | sed 's/\\\(.\)/\1/g')"
[ -n "$WIRING" ] || { echo "    .claude/settings.json no cablea el Centinela" >&2; exit 1; }

TMPD="$(mktemp -d)"
trap 'chmod -R u+rwx "$TMPD" 2>/dev/null; rm -rf "$TMPD"' EXIT
MARK="$TMPD/trampa-ejecutada"
# Programas trampa: si se ejecutan, lo apuntan y dejan pasar (exit 0)
TRAP_BIN="$TMPD/bin"; mkdir -p "$TRAP_BIN"
for p in bash grep sed git awk; do
  printf '#!/bin/sh\necho "%s" >> "%s"\nexit 0\n' "$p" "$MARK" > "$TRAP_BIN/$p"; chmod +x "$TRAP_BIN/$p"
done
printf 'echo BASH_ENV >> "%s"\nexit 0\n' "$MARK" > "$TMPD/bash_env.sh"

# wire <proyecto> <json> [VAR=valor ...] → el cableado, desde un entorno de sesión mínimo más
# las variables dadas; deja RH_EXIT, RH_ERR y RH_OUT
wire() {
  local proj="$1" json="$2"; shift 2
  local errf outf; errf="$(mktemp)"; outf="$(mktemp)"
  ( cd "$proj" && printf '%s' "$json" | /usr/bin/env -i HOME="$HOME" PATH="/usr/bin:/bin" \
      CLAUDE_PROJECT_DIR="$proj" "$@" /bin/sh -c "$WIRING" ) 2>"$errf" >"$outf"
  RH_EXIT=$?; RH_ERR="$(cat "$errf")"; RH_OUT="$(cat "$outf")"
  rm -f "$errf" "$outf"
}

BLOCKED="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/sentinel/policy.yaml\",\"content\":\"rules:\"}}"
INNOCUOUS='{"tool_name":"Bash","tool_input":{"command":"ls"}}'

# ── 06: el entorno de la sesión no elige el Centinela ──────────────────────────────────────
run_env() { # $1=qué es · resto: variables (con BLOCKED_JSON, otra acción que debe bloquearse)
  local what="$1"; shift
  rm -f "$MARK"
  wire "${PROJ:-$REPO_ROOT}" "${BLOCKED_JSON:-$BLOCKED}" "$@"
  assert_exit 2 || { echo "    con $what, el cableado dejó pasar lo bloqueado (exit $RH_EXIT)" >&2; exit 1; }
  [ ! -e "$MARK" ] || { echo "    con $what, el cableado ejecutó: $(tr '\n' ' ' <"$MARK")" >&2; exit 1; }
  wire "${PROJ:-$REPO_ROOT}" "$INNOCUOUS" "$@"
  assert_exit 0 || { echo "    con $what, el cableado bloqueó un ls: $RH_ERR" >&2; exit 1; }
}
run_env "un bash, un grep, un sed, un git y un awk trampa en el PATH" PATH="$TRAP_BIN:/usr/bin:/bin"
run_env "BASH_ENV" BASH_ENV="$TMPD/bash_env.sh" ENV="$TMPD/bash_env.sh"
# SHELLOPTS llega al bash del Centinela: con noglob, el comodín no se expandiría y la carpeta
# pasaría. (Un SHELLOPTS=noexec ya no deja ejecutar nada a la shell con que se lanza el hook,
# antes del cableado: es el límite «La shell que lanza el cableado» de sentinel/README.md)
BLOCKED_JSON='{"tool_name":"Bash","tool_input":{"command":"mv sentin* /tmp/x"}}' \
  run_env "SHELLOPTS=noglob" SHELLOPTS=noglob
run_env "una función grep exportada" 'BASH_FUNC_grep%%=() { echo funcion >> '"$MARK"'; return 1; }' \
  'BASH_FUNC_grep()=() { echo funcion >> '"$MARK"'; return 1; }'
# GIT_DIR llega al git del Centinela: con otro repo, no sabe en qué rama está y un commit en main
# pasaría. Se prueba en un repo en main con el Centinela dentro
trap 'cleanup_workspace; chmod -R u+rwx "$TMPD" 2>/dev/null; rm -rf "$TMPD"' EXIT
mk_workspace && cp -R "$REPO_ROOT/sentinel" "$WS/" && git -C "$WS" checkout -q -B main
PROJ="$WS" BLOCKED_JSON='{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' \
  run_env "GIT_DIR y GIT_CONFIG_* de otro repo" GIT_DIR=/nonexistent GIT_CONFIG_COUNT=1 \
  GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null

# ── 09: el Centinela que no decide, bloquea ────────────────────────────────────────────────
# Claude Code bloquea también si el cableado no puede arrancar o tarda demasiado
# (onFailure: block, revisión de la #13)
grep -A3 'sentinel/hooks/sentinel-guard.sh' "$REPO_ROOT/.claude/settings.json" | grep -q '"onFailure": "block"' \
  || { echo "    el hook del Centinela no lleva onFailure: block" >&2; exit 1; }

P="$TMPD/proyecto"; G="$P/sentinel/hooks/sentinel-guard.sh"
mkdir -p "$P/sentinel/hooks"
fake() { printf '#!/usr/bin/env bash\ncat >/dev/null\n%s\n' "$1" > "$G"; }

# El PATH fijo, con las carpetas del sistema delante, también lleva las de Git for Windows, Nix y
# linuxbrew, donde puede estar el único git de la máquina (revisión de sentinel-paths, P1)
fake 'printf %s "$PATH"; exit 0'
git -C "$P" init -q
wire "$P" "$INNOCUOUS"
case "$RH_OUT" in /usr/bin:/bin:/usr/sbin:/sbin:*) ;; *)
  echo "    el PATH del cableado no empieza por las carpetas del sistema: $RH_OUT" >&2; exit 1 ;; esac
for d in /mingw64/bin /nix/var/nix/profiles/default/bin /home/linuxbrew/.linuxbrew/bin \
         "/etc/profiles/per-user/$(id -un)/bin" "$HOME/.nix-profile/bin"; do
  case ":$RH_OUT:" in *":$d:"*) ;; *) echo "    el PATH del cableado no lleva $d: $RH_OUT" >&2; exit 1 ;; esac
done
rm -rf "$P/.git"

# Sin un git que responda en el proyecto (git fuera del PATH fijo, o no es un repo), el Centinela
# no sabría la rama y las reglas de rama no se aplicarían: 2 y por qué (revisión de la #13). Con
# git instalado, el motivo es lo que dice git, no que falta (P6 = A9: un repo de otro dueño dice
# «dubious ownership» y cómo arreglarlo)
fake 'exit 0'
wire "$P" "$INNOCUOUS"
assert_exit 2 || { echo "    sin un git que responda, el cableado no bloqueó (exit $RH_EXIT)" >&2; exit 1; }
assert_err_contains "not a git repository" || { echo "    el bloqueo no dice lo que dice git: $RH_ERR" >&2; exit 1; }
case "$RH_ERR" in *"Instala git"*) echo "    con git instalado, el bloqueo manda instalarlo: $RH_ERR" >&2; exit 1 ;; esac
git -C "$P" init -q
git -C "$P" add -A && git -C "$P" -c user.email=f@l -c user.name=f commit -qm "con el SDK"
B0="$(git -C "$P" symbolic-ref --short HEAD)"

# Sin el script: 2 y cómo restaurarlo
rm -f "$G"
wire "$P" "$INNOCUOUS"
assert_exit 2 || { echo "    sin el Centinela, el cableado no bloqueó (exit $RH_EXIT)" >&2; exit 1; }
assert_err_contains "sentinel-guard.sh" || { echo "    el bloqueo no dice qué falta: $RH_ERR" >&2; exit 1; }
assert_err_contains "git checkout -- sentinel/hooks" || { echo "    el bloqueo no dice cómo restaurarlo: $RH_ERR" >&2; exit 1; }

# En una rama (o un commit) sin el SDK no hay nada que restaurar: dice cómo volver (P3)
git -C "$P" checkout -q --orphan sin-sdk && git -C "$P" rm -rqf --cached . && rm -rf "$P/sentinel"
git -C "$P" -c user.email=f@l -c user.name=f commit -q --allow-empty -m "sin el SDK"
wire "$P" "$INNOCUOUS"
assert_exit 2 || { echo "    en una rama sin el SDK, el cableado no bloqueó (exit $RH_EXIT)" >&2; exit 1; }
assert_err_contains "no tiene el SDK" || { echo "    el bloqueo no dice que la rama no tiene el SDK: $RH_ERR" >&2; exit 1; }
assert_err_contains "git checkout -" || { echo "    el bloqueo no dice cómo volver: $RH_ERR" >&2; exit 1; }
case "$RH_ERR" in *"git checkout -- sentinel/hooks"*)
  echo "    en una rama sin el SDK, el bloqueo manda restaurar lo que no hay: $RH_ERR" >&2; exit 1 ;; esac
git -C "$P" checkout -q "$B0"

# Ilegible (como root se puede leer igual: ese caso no aplica)
if [ "$(id -u)" != 0 ]; then
  fake 'exit 0'; chmod 000 "$G"
  wire "$P" "$INNOCUOUS"
  assert_exit 2 || { echo "    con el Centinela ilegible, el cableado no bloqueó (exit $RH_EXIT)" >&2; exit 1; }
  chmod 644 "$G"
fi

# Un código que no es una decisión: 2
for rc in 1 3 126 127; do
  fake "exit $rc"
  wire "$P" "$INNOCUOUS"
  assert_exit 2 || { echo "    con un Centinela que sale con $rc, el cableado salió con $RH_EXIT" >&2; exit 1; }
done

# Las decisiones pasan tal cual: 0 con la salida (p. ej. el JSON de confirmar) y 2 con el motivo
fake 'printf %s "{\"decision\":\"ask\"}"; exit 0'
wire "$P" "$INNOCUOUS"
assert_exit 0 || { echo "    un 0 del Centinela no pasó: $RH_EXIT" >&2; exit 1; }
[ "$RH_OUT" = '{"decision":"ask"}' ] || { echo "    la salida del Centinela no llegó al harness: $RH_OUT" >&2; exit 1; }
fake 'echo "sentinel-guard: motivo de prueba" >&2; exit 2'
wire "$P" "$INNOCUOUS"
assert_exit 2 || { echo "    un 2 del Centinela no pasó: $RH_EXIT" >&2; exit 1; }
assert_err_contains "motivo de prueba" || { echo "    el motivo del Centinela no llegó: $RH_ERR" >&2; exit 1; }
exit 0
