#!/usr/bin/env bash
# SC-sentinel-guard-21: ejecutar el instalador reescribe el enforcement y el cableado, así que
# pide aprobación humana (confirm), lo lance como lo lance. Leerlo o buscar en él no la pide.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

fail_case() { echo "    $1" >&2; exit 1; }
bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }
guard() { run_hook "$GUARD_HOOK" "$(bash_payload "$1")" SENTINEL_POLICY_DEFAULT="$DEFAULT_POLICY" SENTINEL_POLICY="$NO_POLICY"; }

for cmd in \
  'bash ../spec-sentinel-sdk/ai-specs/skills/setup/setup.sh .' \
  'bash /opt/sdk/ai-specs/skills/setup/setup.sh' \
  'cd ../app && bash ../sdk/ai-specs/skills/setup/setup.sh .' \
  './ai-specs/skills/setup/setup.sh' \
  'bash -x ai-specs/skills/setup/setup.sh /tmp/repo'; do
  guard "$cmd"
  assert_exit 0 || fail_case "«${cmd}» no debería denegarse, sino pedir aprobación"
  case "$RH_OUT" in *'"ask"'*) ;; *) fail_case "«${cmd}» debería pedir aprobación humana (stdout: $RH_OUT)";; esac
done

for cmd in \
  'cat ai-specs/skills/setup/setup.sh' \
  'grep -n todo ai-specs/skills/setup/setup.sh' \
  'git log -- ai-specs/skills/setup/setup.sh'; do
  guard "$cmd"
  assert_exit 0 || fail_case "«${cmd}» no debería denegarse"
  case "$RH_OUT" in *'"ask"'*) fail_case "«${cmd}» no ejecuta el instalador: no debería pedir aprobación";; esac
done
