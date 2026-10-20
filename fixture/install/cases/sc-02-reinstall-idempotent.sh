#!/usr/bin/env bash
# SC-sdk-setup-02: reinstalar no cambia nada — ni ficheros, ni core.hooksPath, ni entradas
# duplicadas en .claude/settings.json (tampoco con un settings.json previo fusionado).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

mkdir -p "$WS/.claude"
printf '{"permissions":{"allow":["Bash(ls:*)"]}}\n' >"$WS/.claude/settings.json"
printf '{"scripts":{"test":"vitest"}}\n' >"$WS/package.json"

run_setup
assert_exit 0 || fail_case "la primera instalación debería terminar con 0"
before="$(ws_snapshot)"

run_setup
assert_exit 0 || fail_case "la segunda instalación debería terminar con 0"
after="$(ws_snapshot)"

[ "$before" = "$after" ] || fail_case "la reinstalación cambió el workspace:
$(diff <(echo "$before") <(echo "$after"))"
[ "$(settings_count "$WS/.claude/settings.json" sentinel-guard)" -eq 1 ] || fail_case "entrada del Centinela duplicada"
cleanup_git_workspace
