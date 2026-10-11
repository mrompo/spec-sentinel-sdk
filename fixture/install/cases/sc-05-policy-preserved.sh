#!/usr/bin/env bash
# SC-sdk-setup-05: al reinstalar, la política del consumidor y su bitácora se conservan intactas;
# lo distribuido (policy.default.yaml y los hooks) se actualiza, con backup si difería.
# La política del consumidor nace sin reglas, con sdd: true solo si el repo usa OpenSpec, y si
# repite ids del SDK (política anterior a la separación) se avisa: el Centinela la rechazaría.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
SDK_DEFAULT="$REPO_ROOT/sentinel/policy.default.yaml"
[ -f "$SDK_DEFAULT" ] || fail_case "falta sentinel/policy.default.yaml en el SDK"

run_setup
assert_exit 0 || fail_case "la primera instalación debería terminar con 0"

P="$WS/sentinel/policy.yaml"; D="$WS/sentinel/policy.default.yaml"; L="$WS/sentinel/overrides.log"
H="$WS/sentinel/hooks/session-start.sh"
grep -qE '^sdd:[[:space:]]*false' "$P" || fail_case "sin openspec/, la política del consumidor debería nacer con sdd: false"
grep -qE '^[[:space:]]*-[[:space:]]+id:' "$P" && fail_case "la política del consumidor debería nacer sin reglas"
cmp -s "$D" "$SDK_DEFAULT" || fail_case "la política distribuida no se instaló"

# El consumidor añade una regla y usa la bitácora; alguien toca lo distribuido
printf '\n  - id: regla-del-consumidor\n    tool: Bash\n    command_re: make deploy\n    mode: block\n    reason: propia\n' >>"$P"
printf '2026-10-01T00:00:00Z | guard | algo | motivo\n' >>"$L"
printf '# tocado por el consumidor\n' >>"$H"
printf '# tocado por el consumidor\n' >>"$D"
policy="$(cat "$P")"; log="$(cat "$L")"

run_setup
assert_exit 0 || fail_case "la reinstalación debería terminar con 0"
[ "$(cat "$P")" = "$policy" ] || fail_case "la reinstalación pisó la política del consumidor"
[ "$(cat "$L")" = "$log" ] || fail_case "la reinstalación tocó la bitácora"
cmp -s "$H" "$REPO_ROOT/sentinel/hooks/session-start.sh" || fail_case "el hook distribuido no se actualizó"
cmp -s "$D" "$SDK_DEFAULT" || fail_case "la política distribuida no se actualizó"
for rel in sentinel/hooks/session-start.sh sentinel/policy.default.yaml; do
  find "$WS/sentinel/.backup" -path "*/$rel" -type f 2>/dev/null | grep -q . \
    || fail_case "$rel modificado se sobrescribió sin backup"
done

# Política anterior a la separación (repite reglas del SDK): se conserva, pero se avisa
cp "$SDK_DEFAULT" "$P"; policy="$(cat "$P")"
run_setup
assert_exit 3 || fail_case "con ids del SDK repetidos en policy.yaml debería terminar con 3"
assert_out_contains "repite reglas del SDK" || fail_case "no avisa de los ids repetidos"
[ "$(cat "$P")" = "$policy" ] || fail_case "tampoco entonces se toca la política del consumidor"
cleanup_git_workspace

# Con openspec/ en el repo: nivel Método
mk_git_workspace
mkdir -p "$WS/openspec"
run_setup
grep -qE '^sdd:[[:space:]]*true' "$WS/sentinel/policy.yaml" \
  || fail_case "con openspec/, la política del consumidor debería nacer con sdd: true"
cleanup_git_workspace
