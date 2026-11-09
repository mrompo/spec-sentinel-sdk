#!/usr/bin/env bash
# SC-sdk-version-07: en un clon con la instalación versionada (sentinel/.sdk-version en git) y la
# Esclusa sin activar ni encadenar, el aviso de session-start propone setup --activate o
# «git config core.hooksPath sentinel/githooks», no reinstalar el SDK. Sin sentinel/.sdk-version
# versionado (una instalación anterior), no propone --activate, que no tendría qué comprobar.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

START_HOOK="$REPO_ROOT/sentinel/hooks/session-start.sh"
mk_workspace
fail_case() { echo "    $1" >&2; cleanup_workspace; exit 1; }
start() { RH_CWD="$WS" run_hook "$START_HOOK" '{}' CLAUDE_PROJECT_DIR="$WS" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; }

mkdir -p "$WS/sentinel/githooks"
printf 'commit=%s\ndirty=no\n' "$(printf '%040d' 0)" >"$WS/sentinel/.sdk-version"
start
assert_exit 0 || fail_case "session-start nunca debe fallar"
case "$RH_OUT" in *"--activate"*) fail_case "sin sentinel/.sdk-version versionado no debería proponer --activate: $RH_OUT" ;; esac

git -C "$WS" add sentinel/.sdk-version
start
assert_exit 0 || fail_case "session-start nunca debe fallar"
case "$RH_OUT" in *"--activate"*) ;; *) fail_case "con la instalación versionada, el aviso debería proponer setup --activate: $RH_OUT" ;; esac
case "$RH_OUT" in *"git config core.hooksPath sentinel/githooks"*) ;; *) fail_case "el aviso debería seguir dando el comando que la activa: $RH_OUT" ;; esac
case "$RH_OUT" in *"ejecuta setup"*) fail_case "con la instalación versionada, el aviso no debería proponer reinstalar el SDK: $RH_OUT" ;; esac
# Una copia del SDK anterior a sdk-version no conoce --activate: el aviso dice qué hacer (P6)
case "$RH_OUT" in *"no existe el directorio --activate"*) ;; *) fail_case "el aviso debería decir qué hacer si la copia del SDK no conoce --activate: $RH_OUT" ;; esac

git -C "$WS" config core.hooksPath sentinel/githooks
start
case "$RH_OUT" in *"--activate"*) fail_case "con la Esclusa activa no debería avisar: $RH_OUT" ;; esac
cleanup_workspace
