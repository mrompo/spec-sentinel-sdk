#!/usr/bin/env bash
# Slice 6 de git-gates — política distribuida + política del consumidor (opción A):
# SC-sentinel-guard-17: el consumidor añade reglas y se aplican.
# SC-sentinel-guard-18: el consumidor no relaja el SDK (la distribuida se evalúa primero).
# SC-sentinel-guard-19: un id del SDK repetido en la del consumidor es un error de política.
# SC-sentinel-guard-10 (sdd): se lee de la del consumidor y, si no lo declara, de la distribuida.
# SC-sentinel-guard-13: las dos políticas y la variable de la distribuida están protegidas.
# Sin variables, el guard encuentra las dos políticas en la raíz del proyecto.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

mk_workspace
fail_case() { echo "    $1" >&2; cleanup_workspace; exit 1; }
bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }
mkdir -p "$WS/sentinel"
cp "$DEFAULT_POLICY" "$WS/sentinel/policy.default.yaml" 2>/dev/null \
  || fail_case "falta sentinel/policy.default.yaml (la política distribuida)"
C="$WS/sentinel/policy.yaml"
guard() { RH_CWD="$WS" run_hook "$GUARD_HOOK" "$1" CLAUDE_PROJECT_DIR="$WS"; }

# 17 — regla propia del consumidor (descubierta sin variables, desde la raíz del proyecto)
cat >"$C" <<'EOF'
version: 1
rules:
  - id: local-deploy
    tool: Bash
    command_re: make[[:space:]]+deploy
    mode: block
    reason: el despliegue lo hace el pipeline
EOF
guard "$(bash_payload 'make deploy')"
assert_exit 2 || fail_case "17: la regla del consumidor no se aplicó"
assert_err_contains "local-deploy" || fail_case "17: el rechazo no nombra la regla del consumidor"
guard "$(bash_payload 'git push --force origin x')"
assert_exit 2 || fail_case "17: con política del consumidor, las reglas del SDK deben seguir aplicando"
assert_err_contains "no-force-push" || fail_case "17: debería decidir no-force-push"

# 18 — una regla warn del consumidor no adelanta a un block del SDK
cat >"$C" <<'EOF'
version: 1
rules:
  - id: relax-push
    tool: Bash
    command_re: git[[:space:]]+push
    mode: warn
    reason: aviso local
EOF
guard "$(bash_payload 'git push --force origin x')"
assert_exit 2 || fail_case "18: el consumidor relajó una regla del SDK"
assert_err_contains "no-force-push" || fail_case "18: debería decidir la regla del SDK"
guard "$(bash_payload 'git push origin feature/x')"
assert_exit 0 || fail_case "18: un push normal debería pasar"
assert_err_contains "warn:relax-push" || fail_case "18: la regla del consumidor debe aplicar donde el SDK no decide"

# 19 — id del SDK repetido: error de política, aunque la acción sea inocua
cat >"$C" <<'EOF'
version: 1
rules:
  - id: no-force-push
    tool: Bash
    command_re: nunca-coincide
    mode: warn
    reason: intento de sustituir la regla del SDK
EOF
guard "$(bash_payload 'echo hola')"
assert_exit 2 || fail_case "19: un id duplicado debería ser error de política"
assert_err_contains "no-force-push" || fail_case "19: el error no nombra el id duplicado"

# 20 — entre las dos políticas gana la decisión más estricta: un warn o confirm del SDK no tapa un
# block del consumidor, y un confirm del consumidor gana a un warn del SDK
cat >"$C" <<'EOF'
version: 1
rules:
  - id: no-coverage-edits
    tool: Edit|Write
    path_re: jest\.config
    mode: block
    reason: la cobertura la cambia QA
  - id: no-rm-build
    tool: Bash
    command_re: rm[[:space:]]+-rf[[:space:]]+build
    mode: block
    reason: build lo limpia el pipeline
  - id: ask-release
    tool: Bash
    command_re: make[[:space:]]+release
    mode: confirm
    reason: el release lo aprueba una persona
EOF
guard '{"tool_name":"Edit","tool_input":{"file_path":"jest.config.js","new_string":"x"}}'
assert_exit 2 || fail_case "20: un warn del SDK (coverage-thresholds) tapó un block del consumidor"
assert_err_contains "no-coverage-edits" || fail_case "20: debería decidir la regla del consumidor"
guard "$(bash_payload 'rm -rf build')"
assert_exit 2 || fail_case "20: un confirm del SDK (destructive) tapó un block del consumidor"
assert_err_contains "no-rm-build" || fail_case "20: debería decidir la regla del consumidor"
guard "$(bash_payload 'make release # vitest.config')"
case "$RH_OUT" in *'"ask"'*ask-release*) ;; *) fail_case "20: un confirm del consumidor debería ganar a un warn del SDK (stdout: $RH_OUT)";; esac

# sdd — la del consumidor manda; sin declararlo, hereda la distribuida (que trae sdd: false:
# el nivel Método lo activa cada proyecto)
EDIT_SRC='{"tool_name":"Edit","tool_input":{"file_path":"src/app.js","new_string":"x"}}'
grep -qE '^sdd:[[:space:]]*false' "$WS/sentinel/policy.default.yaml" \
  || fail_case "la política distribuida debería traer sdd: false (nivel Guardia por defecto)"
printf 'version: 1\nsdd: true\nrules:\n' >"$C"
guard "$EDIT_SRC"
assert_err_contains "warn:spec-guard" || fail_case "sdd: true del consumidor debería activar spec-guard"
printf 'version: 1\nrules:\n' >"$C"
guard "$EDIT_SRC"
[ -z "$RH_ERR" ] || fail_case "sin sdd en el consumidor hereda sdd: false: no debería avisar ($RH_ERR)"
sed -i.bak 's/^sdd:.*/sdd: true/' "$WS/sentinel/policy.default.yaml"
guard "$EDIT_SRC"
assert_err_contains "warn:spec-guard" || fail_case "sin sdd en el consumidor debería heredar el de la distribuida"
printf 'version: 1\nsdd: false\nrules:\n' >"$C"
guard "$EDIT_SRC"
[ -z "$RH_ERR" ] || fail_case "sdd: false del consumidor manda sobre la distribuida ($RH_ERR)"

# AGENTS.md es del consumidor: la política distribuida no lo protege (P3-3). En el SDK lo protege
# su propia policy.yaml, también a través de los enlaces CLAUDE.md, GEMINI.md y codex.md
printf 'version: 1\nrules:\n' >"$C"
for f in AGENTS.md packages/api/AGENTS.md CLAUDE.md; do
  guard "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$f\",\"new_string\":\"x\"}}"
  assert_exit 0 || fail_case "en un consumidor, editar $f no debería bloquearse ($RH_ERR)"
done
for f in AGENTS.md CLAUDE.md GEMINI.md codex.md; do
  run_hook "$GUARD_HOOK" "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$f\",\"new_string\":\"x\"}}" \
    SENTINEL_POLICY_DEFAULT="$DEFAULT_POLICY" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || fail_case "en el SDK, editar $f debería bloquearse (lo protege su policy.yaml)"
done

# 13 — las dos políticas y la variable de la distribuida están protegidas
for payload in \
  '{"tool_name":"Write","tool_input":{"file_path":"sentinel/policy.default.yaml","content":"version: 1\nrules:\n"}}' \
  '{"tool_name":"Edit","tool_input":{"file_path":"sentinel/policy.yaml","new_string":"x"}}' \
  "$(bash_payload 'rm sentinel/policy.default.yaml')" \
  "$(bash_payload 'SENTINEL_POLICY_DEFAULT=/tmp/vacia.yaml claude')" \
  "$(bash_payload 'SENTINEL_SETUP_JQ=./myjq bash ../sdk/ai-specs/skills/setup/setup.sh .')" \
  "$(bash_payload 'env SENTINEL_CUALQUIERA=1 make test')"; do
  guard "$payload"
  assert_exit 2 || fail_case "13: debería bloquearse: $payload"
done
cleanup_workspace
