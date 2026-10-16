#!/usr/bin/env bash
# SC-sdk-setup-11: si el .gitignore deja fuera lo que hay que versionar (la plantilla de Node
# ignora *.log; hay repos que ignoran .claude/), setup lo dice con exit 3; arreglado, sale con 0.
# SC-sdk-setup-12: si al terminar el Centinela instalado deniega una acción inocua, exit 3 con su
# motivo. Y antes de tocar un fichero existente (.gitignore, stack.proposed.yaml), backup.
# Review: A5 = P6, A6, A9.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh" || exit 1

fail_case() { echo "    $1" >&2; cleanup_git_workspace; exit 1; }

# a) .gitignore que ignora la bitácora y el cableado
mk_git_workspace
printf 'node_modules/\n*.log\n.claude/\n' >"$WS/.gitignore"; orig_gi="$(cat "$WS/.gitignore")"
run_setup
assert_exit 3 || fail_case "con la bitácora y el cableado ignorados debería terminar con 3"
assert_out_contains "sentinel/overrides.log" || fail_case "no nombra la bitácora ignorada"
assert_out_contains ".claude/settings.json" || fail_case "no nombra el cableado ignorado"
assert_out_contains "!sentinel/overrides.log" || fail_case "no da la excepción que hay que añadir"
gi_backup="$(find "$WS/sentinel/.backup" -name .gitignore -type f 2>/dev/null | head -1)"
[ -n "$gi_backup" ] && [ "$(cat "$gi_backup")" = "$orig_gi" ] || fail_case "se tocó el .gitignore sin backup del original"
printf 'node_modules/\n*.log\n.claude/*\n!.claude/settings.json\n!sentinel/overrides.log\nsentinel/.override\nsentinel/.backup/\n' >"$WS/.gitignore"
run_setup
assert_exit 0 || fail_case "con las excepciones puestas debería terminar con 0: $RH_ERR"
git_in_ws add -A -- . ':!.gl-ok'
git_in_ws ls-files --error-unmatch sentinel/overrides.log .claude/settings.json >/dev/null 2>&1 \
  || fail_case "con las excepciones, la bitácora y el cableado deberían versionarse"
cleanup_git_workspace

# b) el Centinela instalado deniega todo: política del consumidor con una regla sin mode, o vacía
mk_git_workspace
run_setup
assert_exit 0 || fail_case "la instalación en un repo limpio debería terminar con 0"
printf 'version: 1\nrules:\n  - id: mia\n    tool: Bash\n    command_re: deploy\n' >>"$WS/sentinel/policy.yaml"
run_setup
assert_exit 3 || fail_case "con un Centinela que lo deniega todo debería terminar con 3"
assert_out_contains "mode:" || fail_case "no muestra el motivo que da el Centinela"
: >"$WS/sentinel/policy.yaml"
run_setup
assert_exit 3 || fail_case "con la política del consumidor vacía debería terminar con 3"
assert_out_contains "ilegible" || fail_case "no muestra el motivo que da el Centinela (política ilegible)"
cleanup_git_workspace

# c) la propuesta de stack revisada por una persona no se pierde al reinstalar
mk_git_workspace
printf '{"scripts":{"test":"vitest","lint":"eslint ."}}\n' >"$WS/package.json"
run_setup
P="$WS/sentinel/adapters/stack.proposed.yaml"
[ -f "$P" ] || fail_case "debería proponerse un stack para un repo Node"
printf '# revisado: sin lint\n' >>"$P"; edited="$(cat "$P")"
run_setup
bk="$(find "$WS/sentinel/.backup" -name stack.proposed.yaml -type f 2>/dev/null | head -1)"
[ -n "$bk" ] && [ "$(cat "$bk")" = "$edited" ] || fail_case "se sobrescribió la propuesta revisada sin backup"
cleanup_git_workspace
