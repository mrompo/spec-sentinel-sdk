#!/usr/bin/env bash
# Autotest del runner de git hooks: si el harness no detectara un hook que rechaza, todos los
# demás casos pasarían en falso. Un hook que siempre falla debe rechazar el commit; uno que
# siempre pasa debe dejarlo entrar; y el config global del usuario no debe filtrarse.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

mk_git_workspace
fake="$WS/.fake-hooks"; mkdir -p "$fake"
printf '#!/usr/bin/env bash\necho "rechazado por el hook falso" >&2\nexit 1\n' >"$fake/commit-msg"
chmod +x "$fake/commit-msg"
use_hooks "$fake"

echo x >"$WS/a.txt"; git_in_ws add a.txt
gh_commit "feat: algo"
assert_exit 1 || { cleanup_git_workspace; exit 1; }
assert_err_contains "rechazado por el hook falso" || { cleanup_git_workspace; exit 1; }

printf '#!/usr/bin/env bash\nexit 0\n' >"$fake/commit-msg"
gh_commit "feat: algo"
assert_exit 0 || { cleanup_git_workspace; exit 1; }

# Aislamiento: el config global del usuario (firmas, hooksPath propio…) no entra en el banco
[ "$(git_in_ws config --global --get user.name 2>/dev/null || true)" = "" ] \
  || { echo "    el config global del usuario se filtra al workspace" >&2; cleanup_git_workspace; exit 1; }
cleanup_git_workspace
