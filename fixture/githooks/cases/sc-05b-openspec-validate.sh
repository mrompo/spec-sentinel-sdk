#!/usr/bin/env bash
# SC-git-gates-05 (Barrera antes de publicar, nivel Método): con sdd: true y openspec/ en el
# repo, pre-push ejecuta `openspec validate --strict`; si falla, rechaza. Sin el CLI, avisa y
# sigue (decisión 4: la Aduana lo hará obligatorio). Con sdd: false no se ejecuta.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
mkdir -p "$WS/sentinel" "$WS/openspec/changes" "$WS/.bin"
printf 'version: 1\nsdd: true\nrules:\n' >"$WS/sentinel/policy.yaml"
printf '#!/usr/bin/env bash\necho "✗ change/x: spec inválida"\nexit 1\n' >"$WS/.bin/openspec"
chmod +x "$WS/.bin/openspec"

gh_push HEAD:feature/fixture SENTINEL_OPENSPEC_BIN="$WS/.bin/openspec"
assert_exit 1 || fail_case "con la spec inválida el push no debería entrar"
assert_err_contains "spec inválida" || fail_case "no muestra la salida de openspec"

gh_push HEAD:feature/fixture SENTINEL_OPENSPEC_BIN=/nonexistent/openspec
assert_exit 0 || fail_case "sin el CLI el push debería entrar"
assert_err_contains "openspec no está instalado" || fail_case "sin el CLI no avisa"

# Nivel Guardia (sdd: false): no se valida aunque el CLI falle
printf 'version: 1\nsdd: false\nrules:\n' >"$WS/sentinel/policy.yaml"
git_in_ws commit -q --allow-empty -m "feat: otro"
gh_push HEAD:feature/fixture SENTINEL_OPENSPEC_BIN="$WS/.bin/openspec"
assert_exit 0 || fail_case "con sdd: false no debería validar las specs"
cleanup_git_workspace
