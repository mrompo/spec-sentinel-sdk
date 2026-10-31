#!/usr/bin/env bash
# SC-sentinel-paths-10 (revisión de la #18): en un repo sin commits, la rama es la de HEAD (p. ej.
#   `main`), no `HEAD`, así que protected-branches bloquea el primer commit en main. En una rama
#   feature sin commits pasa, y con HEAD desligado no hay rama y las reglas de rama no se aplican.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail_case() { echo "    $1" >&2; exit 1; }
COMMIT='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"x\""}}'
guard() { RH_CWD="$T" run_hook "$GUARD_HOOK" "$COMMIT" -u CLAUDE_PROJECT_DIR SENTINEL_POLICY_DEFAULT="$DEFAULT_POLICY" SENTINEL_POLICY="$CONSUMER_POLICY"; }

git -C "$T" init -q && git -C "$T" symbolic-ref HEAD refs/heads/main
guard
assert_exit 2 || fail_case "el primer commit en main de un repo sin commits debería bloquearse"
assert_err_contains "Rama protegida" || fail_case "el bloqueo debería ser el de la rama protegida: $RH_ERR"

git -C "$T" symbolic-ref HEAD refs/heads/feature/algo
guard
assert_exit 0 || fail_case "el primer commit en una rama feature sin commits debería pasar"

git -C "$T" -c user.email=f@l -c user.name=f commit -q --allow-empty -m "x" && git -C "$T" checkout -q --detach
guard
assert_exit 0 || fail_case "con HEAD desligado no hay rama protegida que aplicar"
exit 0
