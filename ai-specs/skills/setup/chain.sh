#!/usr/bin/env bash
# chain.sh — las líneas que encadenan la Esclusa en git hooks que ya existen (husky, .git/hooks,
# un core.hooksPath propio o global). Las imprime setup y las aplica el banco: una sola fuente.
# Se carga con `source`; las líneas que produce son POSIX sh (los hooks ajenos suelen ser sh).
#
# Van AL PRINCIPIO del hook: un `exit` o un `exec` del hook ajeno no se las salta. En pre-push
# guardan las refs de stdin y se las devuelven al resto del hook (git-lfs las necesita). La
# guarda [ -x … ] hace que no hagan nada en un repo sin la Esclusa: un hooksPath global no rompe
# los demás repos de la máquina. Los hooks se ejecutan desde la raíz del repo, de ahí la ruta
# relativa. Falsifica: SC-sdk-setup-08 (fixture/install/cases/sc-08, sc-10).

# chain_snippet <hook> → las líneas para <hook> (commit-msg | pre-commit | pre-push)
chain_snippet() {
  case "$1" in
    pre-push)
      cat <<'EOF'
# spec-sentinel: la Esclusa (al principio; devuelve las refs de stdin al resto del hook)
if [ -x sentinel/githooks/pre-push ]; then
  sentinel_refs="$(mktemp)" || exit 1
  cat >"$sentinel_refs"
  sentinel/githooks/pre-push "$@" <"$sentinel_refs" || { rm -f "$sentinel_refs"; exit 1; }
  exec <"$sentinel_refs"; rm -f "$sentinel_refs"
fi
EOF
      ;;
    commit-msg|pre-commit)
      printf '# spec-sentinel: la Esclusa (al principio)\n'
      printf 'if [ -x sentinel/githooks/%s ]; then sentinel/githooks/%s "$@" || exit 1; fi\n' "$1" "$1"
      ;;
    *) return 1 ;;
  esac
}

# chain_done <dir> [exec] → 0 si commit-msg, pre-commit y pre-push de <dir> ya llaman a la
# Esclusa (con «exec», además tienen que ser ejecutables: git ignora un hook que no lo es)
chain_done() {
  local h
  for h in commit-msg pre-commit pre-push; do
    grep -qF "sentinel/githooks/$h \"\$@\"" "$1/$h" 2>/dev/null || return 1
    [ "${2:-}" != exec ] || [ -x "$1/$h" ] || return 1
  done
}
