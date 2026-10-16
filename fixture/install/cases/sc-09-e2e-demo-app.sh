#!/usr/bin/env bash
# Slice 8 de git-gates, DoD de la fase 2 (SC-sdk-setup-01 de punta a punta): el recorrido de un
# consumidor sobre demo-app. Instala, commitea la instalación y cada puesto bloquea con los
# ficheros INSTALADOS, sin nada del banco: la Esclusa con sus tres hooks (SC-git-gates-01, 03,
# 05) y el Centinela con las dos políticas (SC-sentinel-guard-13, 17).
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
gl="$(gl_ok)"

# ── 1. Instalar y commitear la instalación: la Esclusa no se bloquea con sus propios ficheros ──
run_setup
assert_exit 0 || fail_case "la instalación en demo-app debería terminar con 0 (salió $RH_EXIT)"
git_in_ws add -A -- . ':!.gl-ok'
_capture env "$gl" git commit -q -m "chore: instala spec-sentinel (nivel Guardia)"
assert_exit 0 || fail_case "la Esclusa rechazó el commit de la propia instalación: $RH_ERR"

# ── 2. Esclusa · pre-commit: un secreto en staging no entra ──────────────────────────────────
aws="AKIA""IOSFODNN7EXAMPLE"   # compuesto en ejecución: este fichero no es un secreto
printf 'key = "%s"\n' "$aws" >"$WS/app.env"
git_in_ws add app.env
_capture env "$gl" git commit -q -m "feat: configuración"
assert_exit 1 || fail_case "la Esclusa instalada aceptó un secreto"
assert_err_contains "app.env" || fail_case "el rechazo del secreto no señala el fichero"
git_in_ws rm -q --cached app.env; rm -f "$WS/app.env"

# ── 3. Esclusa · commit-msg: el mensaje sigue Conventional Commits ───────────────────────────
printf 'hola\n' >"$WS/hola.txt"; git_in_ws add hola.txt
_capture env "$gl" git commit -q -m "añadido hola"
assert_exit 1 || fail_case "la Esclusa instalada aceptó un mensaje no conforme"
_capture env "$gl" git commit -q -m "feat: saludo"
assert_exit 0 || fail_case "la Esclusa instalada rechazó un commit conforme: $RH_ERR"

# ── 4. Esclusa · pre-push: la rama protegida sale de la política distribuida instalada ───────
gh_push HEAD:main
assert_exit 1 || fail_case "la Esclusa instalada aceptó un push a main"
assert_err_contains "rama protegida" || fail_case "el rechazo del push no lo explica"
gh_push HEAD:feature/fixture
assert_exit 0 || fail_case "la Esclusa instalada rechazó un push a una rama feature: $RH_ERR"

# ── 5. Centinela, con el comando que cablea settings.json ───────────────────────────────────
S="$WS/.claude/settings.json"
guard="$(jq -r '.hooks.PreToolUse[].hooks[].command | select(contains("sentinel-guard"))' "$S")"
start="$(jq -r '.hooks.SessionStart[].hooks[].command | select(contains("sentinel/hooks/"))' "$S")"
[ -n "$guard" ] && [ -n "$start" ] || fail_case "settings.json no cablea el Centinela"
payload="$WS.payload.json"
agent() { # agent <json del tool call> → el Centinela instalado lo evalúa como lo haría el harness
  printf '%s' "$1" >"$payload"
  _capture env CLAUDE_PROJECT_DIR="$WS" bash -c "$guard" <"$payload"
}

# El agente no puede tocar ninguna de las dos políticas (autoprotección)
for f in sentinel/policy.default.yaml sentinel/policy.yaml; do
  agent "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WS/$f\",\"content\":\"rules:\"}}"
  assert_exit 2 || { rm -f "$payload"; fail_case "el Centinela instalado dejó al agente escribir $f"; }
done

# Una persona añade una regla del proyecto: se aplica, y lo normal sigue pasando
cat >>"$WS/sentinel/policy.yaml" <<'EOF'
  - id: demo-no-deploy
    tool: Bash
    command_re: make[[:space:]]+deploy
    mode: block
    reason: En demo-app el deploy lo hace CI
EOF
agent '{"tool_name":"Bash","tool_input":{"command":"make deploy"}}'
assert_exit 2 || { rm -f "$payload"; fail_case "la regla del proyecto no se aplicó"; }
assert_err_contains "demo-no-deploy" || { rm -f "$payload"; fail_case "el bloqueo no nombra la regla del proyecto"; }
agent '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
assert_exit 0 || { rm -f "$payload"; fail_case "el Centinela instalado bloqueó un comando inocuo: $RH_ERR"; }
rm -f "$payload"

# El arranque de sesión da contexto y nunca bloquea
_capture env CLAUDE_PROJECT_DIR="$WS" bash -c "$start" </dev/null
assert_exit 0 || fail_case "session-start instalado falló"
assert_err_contains "[sentinel] Rama: feature/fixture" || fail_case "session-start no da el contexto de la rama"

cleanup_git_workspace
