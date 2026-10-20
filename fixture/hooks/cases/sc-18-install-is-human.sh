#!/usr/bin/env bash
# SC-sentinel-guard-21: ejecutar el instalador reescribe el enforcement y el cableado, así que
# pide aprobación humana (confirm), lo lance como lo lance. Cualquier comando de shell que nombre
# el instalador también la pide (la persona ve el comando). Leerlo con Read no la pide.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

fail_case() { echo "    $1" >&2; exit 1; }
bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }
guard() { run_hook "$GUARD_HOOK" "$(bash_payload "$1")" SENTINEL_POLICY_DEFAULT="$DEFAULT_POLICY" SENTINEL_POLICY="$NO_POLICY"; }

for cmd in \
  'bash ~/.claude/skills/spec-sentinel-setup/setup.sh .' \
  'bash /Users/me/.claude/skills/spec-sentinel-setup/setup.sh /Users/me/app' \
  'bash ../spec-sentinel-sdk/ai-specs/skills/setup/setup.sh .' \
  'bash /opt/sdk/ai-specs/skills/setup/setup.sh' \
  'cd ../app && bash ../sdk/ai-specs/skills/setup/setup.sh .' \
  './ai-specs/skills/setup/setup.sh' \
  'bash -x ai-specs/skills/setup/setup.sh /tmp/repo'; do
  guard "$cmd"
  assert_exit 0 || fail_case "«${cmd}» no debería denegarse, sino pedir aprobación"
  case "$RH_OUT" in *'"ask"'*) ;; *) fail_case "«${cmd}» debería pedir aprobación humana (stdout: $RH_OUT)";; esac
done

# Desde la shell, cualquier comando que nombre el instalador pide aprobación: también los que lo
# leen y los que lo modifican (V2-5); la persona decide viendo el comando
for cmd in \
  'cat ai-specs/skills/setup/setup.sh' \
  'grep -n todo ai-specs/skills/setup/chain.sh' \
  'echo x >> ai-specs/skills/setup/chain.sh'; do
  guard "$cmd"
  assert_exit 0 || fail_case "«${cmd}» no debería denegarse, sino pedir aprobación"
  case "$RH_OUT" in *'"ask"'*) ;; *) fail_case "«${cmd}» nombra el instalador: debería pedir aprobación (stdout: $RH_OUT)";; esac
done

# Con las herramientas de lectura, leerlo no pide nada
for f in ai-specs/skills/setup/setup.sh ai-specs/skills/setup/chain.sh; do
  run_hook "$GUARD_HOOK" "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$f\"}}" \
    SENTINEL_POLICY_DEFAULT="$DEFAULT_POLICY" SENTINEL_POLICY="$NO_POLICY"
  assert_exit 0 || fail_case "leer $f con Read no debería bloquearse"
  case "$RH_OUT" in *'"ask"'*) fail_case "leer $f con Read no debería pedir aprobación";; esac
done

# Una skill «setup» propia del consumidor no es el instalador del SDK: se ejecuta sin aprobación
# (A4-7)
for cmd in 'bash .claude/skills/setup/setup.sh' 'bash ~/.claude/skills/setup/setup.sh .'; do
  guard "$cmd"
  assert_exit 0 || fail_case "«${cmd}» no es el instalador del SDK: no debería denegarse"
  case "$RH_OUT" in *'"ask"'*) fail_case "«${cmd}» no es el instalador del SDK: no debería pedir aprobación";; esac
done

# Pedir aprobación para instalar no rebaja ninguna otra regla: si el mismo comando hace algo que
# el SDK bloquea, se bloquea (SC-sentinel-guard-20, 21)
guard 'bash ../sdk/ai-specs/skills/setup/setup.sh . && git push --force origin x'
assert_exit 2 || fail_case "un comando que instala y además hace force-push debería bloquearse"
assert_err_contains "no-force-push" || fail_case "debería decidir no-force-push, no la aprobación de instalar"

# Dentro de la política del SDK también gana la más estricta: borrar la configuración de tests
# pide confirmación (destructive), no se queda en el aviso de coverage-thresholds
guard 'rm -rf jest.config.js'
case "$RH_OUT" in *'"ask"'*destructive*) ;; *) fail_case "borrar jest.config.js debería pedir confirmación (destructive), no solo avisar (stdout: $RH_OUT)";; esac
