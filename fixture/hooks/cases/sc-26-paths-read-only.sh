#!/usr/bin/env bash
# SC-sentinel-paths-08: leer desde la shell un fichero protegido por self-protection o
#   managed-files no se bloquea cuando el comando solo lee (lista cerrada de lectores, sin
#   redirecciones, sustituciones ni opciones que escriben). Lo que escribe, aunque empiece
#   leyendo, sigue bloqueado, e isolation-env sigue bloqueando la lectura.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$DEFAULT_POLICY"

esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$(esc "$1")"; }
guard() { run_hook "$GUARD_HOOK" "$(bash_payload "$1")" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"; }

while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$cmd"
  assert_exit 0 || { echo "    debería permitirse (solo lee): $cmd" >&2; exit 1; }
done <<'EOF'
tail -3 sentinel/overrides.log
grep -n llave openspec/specs/git-gates/spec.md
git diff main -- sentinel/policy.yaml
git log --oneline -3 -- sentinel/policy.default.yaml
git show HEAD:sentinel/hooks/sentinel-guard.sh
cat .git/config
head -20 sentinel/hooks/sentinel-guard.sh | wc -l
cd docs && grep -rn llave ../sentinel/README.md 2>/dev/null
ls -la sentinel/hooks && echo ---
grep -c x CHANGELOG.md 2>&1 | head -1
cat ~/.gitconfig
EOF

while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  guard "$cmd"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done <<'EOF'
cat x > sentinel/policy.yaml
cat sentinel/policy.yaml >> /tmp/copia
tail sentinel/overrides.log | tee sentinel/.override
cat $(echo sentinel/policy.yaml)
cat `echo sentinel/policy.yaml`
cat sentinel/policy.yaml <(rm -f x)
git -c core.pager=cat diff sentinel/policy.yaml
git -C . diff sentinel/policy.yaml
git diff --output=sentinel/policy.yaml
sed -n 1p sentinel/policy.yaml
FOO=1 cat sentinel/policy.yaml
cat x; rm sentinel/policy.yaml
cat sentinel/policy.yaml && sed -i.b s/a/b/ sentinel/policy.yaml
cat .env.production
grep -n x openspec/specs/a/spec.md > openspec/specs/a/spec.md
cp -r sentinel /tmp/copia
EOF

# Un separador o una redirección escritos en el JSON como \u00XX (> ; & y el salto de línea)
# son los mismos para la shell: el comando no cuenta como solo lectura. La barra se construye
# aquí para que el fichero lleve el escape tal cual
U='\'u
for cmd in "cat x ${U}003e sentinel/policy.yaml" "cat x${U}003b rm sentinel/policy.yaml" \
  "cat x ${U}0026${U}0026 rm sentinel/policy.yaml" "cat x${U}000arm sentinel/policy.yaml"; do
  run_hook "$GUARD_HOOK" "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}" \
    SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"
  assert_exit 2 || { echo "    debería bloquearse: $cmd" >&2; exit 1; }
done
exit 0
