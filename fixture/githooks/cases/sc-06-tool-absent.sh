#!/usr/bin/env bash
# SC-git-gates-06: comando del adaptador sin su herramienta (exit 127) → aviso visible de lo que
# se omite y se continúa. Y gitleaks presente se usa de verdad: si encuentra algo, bloquea.
# (gitleaks AUSENTE no es un skip: es obligatorio, SC-git-gates-10.)
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
use_hooks
fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }
printf 'limpio\n' >"$WS/a.txt"; git_in_ws add a.txt

# gitleaks presente (falso) que encuentra una fuga → bloquea con su salida
fake="$WS/.bin"; mkdir -p "$fake"
printf '#!/usr/bin/env bash\necho "leak encontrado por gitleaks falso"\nexit 1\n' >"$fake/gitleaks"
chmod +x "$fake/gitleaks"
printf 'otro\n' >"$WS/b.txt"; git_in_ws add b.txt
_capture env SENTINEL_GITLEAKS_BIN="$fake/gitleaks" git commit -q -m "feat: b"
assert_exit 1 || fail_case "un gitleaks que encuentra fugas debería bloquear"
assert_err_contains "leak encontrado por gitleaks falso" || fail_case "no muestra la salida de gitleaks"

# Comando del adaptador declarado pero no instalado (exit 127) → skip con aviso, no fallo
mkdir -p "$WS/sentinel/adapters"
printf 'lint: comando-que-no-existe-xyz\n' >"$WS/sentinel/adapters/stack.yaml"
_capture env "$(gl_ok)" git commit -q -m "feat: b"
assert_exit 0 || fail_case "un comando no instalado debería omitirse, no fallar"
assert_err_contains "lint" || fail_case "no avisa de que omite lint"
cleanup_git_workspace
