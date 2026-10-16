#!/usr/bin/env bash
# Harness del runner de instalación (fixture, fase 2+) — el banco de la skill `setup`.
# Reutiliza el workspace de la Esclusa (repo desechable con remoto bare) y ejecuta el instalador
# real contra él, como lo haría la skill en el repo de un consumidor.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../githooks/harness.sh" || exit 1
SETUP="$REPO_ROOT/ai-specs/skills/setup/setup.sh"

# run_setup [VAR=valor …] → ejecuta el instalador sobre el workspace y deja RH_EXIT/RH_ERR.
# gitleaks es obligatorio para la Esclusa y el banco no depende de tenerlo: por defecto se usa
# el gitleaks falso de gl_ok; un caso puede sobrescribirlo (env aplica la última asignación).
run_setup() {
  [ -f "$SETUP" ] || { RH_EXIT=127; RH_ERR="falta $SETUP"; RH_OUT="$RH_ERR"; return; }
  _capture env "$(gl_ok)" "$@" bash "$SETUP" "$WS"
}

# ws_commit <mensaje> → commit en el workspace con el gitleaks falso (los hooks ya instalados)
ws_commit() { _capture env "$(gl_ok)" git commit -q --allow-empty -m "$1"; }

# ws_snapshot → huella del workspace (ficheros fuera de .git + core.hooksPath), para comparar
ws_snapshot() {
  ( cd "$WS" && find . -path ./.git -prune -o -path ./.gl-ok -prune -o -type f -print \
      | LC_ALL=C sort | while IFS= read -r f; do printf '%s %s\n' "$(cksum <"$f")" "$f"; done
    printf 'hooksPath=%s\n' "$(git config --get core.hooksPath || true)" )
}

# settings_count <fichero> <texto> → cuántos hooks de settings.json llevan <texto> en su comando
settings_count() {
  jq "[.hooks[]?[]?.hooks[]?.command | select(contains(\"$2\"))] | length" "$1"
}

# assert_out_contains → alias legible: la salida del instalador va por stdout y stderr
assert_out_contains() { assert_err_contains "$1"; }

# assert_out_lacks <texto> → la salida del instalador NO contiene <texto>
assert_out_lacks() {
  printf '%s' "$RH_ERR" | grep -qF -- "$1" || return 0
  echo "    la salida contiene «$1» y no debería" >&2; return 1
}

# chain_into <fichero> <hook> → hace lo que setup pide a la persona: pone las líneas de
# encadenado (las mismas que imprime setup, de chain.sh) al principio del hook, tras el shebang
# si lo hay; si el hook no existe, lo crea ejecutable
CHAIN="$REPO_ROOT/ai-specs/skills/setup/chain.sh"
chain_into() {
  local f="$1" h="$2" tmp
  [ -f "$CHAIN" ] || { echo "    falta $CHAIN (las líneas de encadenado de setup)" >&2; return 1; }
  tmp="$(mktemp)"
  {
    if [ -f "$f" ] && head -1 "$f" | grep -q '^#!'; then head -1 "$f"; else printf '#!/bin/sh\n'; fi
    ( source "$CHAIN" && chain_snippet "$h" )
    if [ -f "$f" ]; then
      if head -1 "$f" | grep -q '^#!'; then tail -n +2 "$f"; else cat "$f"; fi
    fi
  } >"$tmp" || { rm -f "$tmp"; return 1; }
  mkdir -p "$(dirname "$f")" && mv "$tmp" "$f" && chmod +x "$f"
}
