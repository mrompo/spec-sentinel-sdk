#!/usr/bin/env bash
# setup.sh — instala el nivel Guardia (Centinela + Esclusa) en un repo con un solo comando.
#
#   bash <sdk>/ai-specs/skills/setup/setup.sh [raíz-del-repo]      (por defecto, el directorio actual)
#
# Lo invoca la skill `setup` (SKILL.md, al lado); también se puede ejecutar a mano. Idempotente:
# una segunda ejecución no cambia nada. Nunca pisa la configuración del consumidor:
#   - lo distribuido (hooks, githooks, lector del adaptador, policy.default.yaml) se instala o
#     actualiza, con backup si el fichero del consumidor difería;
#   - lo del consumidor (policy.yaml, overrides.log, stack.yaml) solo se crea si no existe;
#     policy.yaml nace sin reglas: las del SDK viven en policy.default.yaml y se evalúan antes;
#   - .claude/settings.json se fusiona con jq; sin jq, o si la fusión no es segura, se deja
#     sentinel/settings.fragment.json y se explica el paso manual;
#   - core.hooksPath solo se activa si el repo no usa ya otros git hooks; si los usa, se dan
#     las líneas que encadenan la Esclusa en ellos (chain.sh) y se reconoce cuando ya están.
# Los backups van a sentinel/.backup/<fecha>/ (fuera de git).
#
# Salida: 0 instalado · 3 instalado con pasos pendientes (se listan) · 1 error. Si falla una
# comprobación previa no se escribe nada; si falla a mitad, lo hecho se queda y reejecutar es seguro.
# Variables: SENTINEL_SETUP_JQ (binario de jq), SENTINEL_GITLEAKS_BIN (el mismo que la Esclusa).
# Falsifica: SC-sdk-setup-01..08 (fixture/install/cases/).
set -uo pipefail

SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
JQ="${SENTINEL_SETUP_JQ:-jq}"
GITLEAKS="${SENTINEL_GITLEAKS_BIN:-gitleaks}"
HOOKS_PATH="sentinel/githooks"

pending=0
die()  { echo "✗ [setup] $1" >&2; exit 1; }
ok()   { echo "✓ $1"; }
note() { echo "· $1"; }
todo() { echo "⚠ PENDIENTE: $1"; pending=1; }

# ── Comprobaciones: nada se escribe hasta que todo cuadra ────────────────────────────────
[ -f "$SDK_ROOT/sentinel/hooks/sentinel-guard.sh" ] && [ -f "$SDK_ROOT/sentinel/policy.default.yaml" ] \
  && [ -f "$SDK_ROOT/ai-specs/skills/setup/chain.sh" ] && [ -f "$SDK_ROOT/.claude/settings.json" ] \
  || die "SDK incompleto en $SDK_ROOT: falta sentinel/, chain.sh o .claude/settings.json — ejecuta setup.sh desde una copia íntegra del SDK"
# shellcheck source=chain.sh
source "$SDK_ROOT/ai-specs/skills/setup/chain.sh"
[ -d "${1:-.}" ] || die "no existe el directorio ${1:-.}"
TARGET="$(cd "${1:-.}" && pwd -P)"
TOP="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)" \
  || die "$TARGET no es un repo git — inicialízalo (git init) y vuelve a ejecutar setup"
# Solo en la raíz: dentro de un subdirectorio, la instalación caería en otro sitio (o en un repo padre)
[ "$(cd "$TOP" && pwd -P)" = "$TARGET" ] \
  || die "$TARGET no es la raíz del repo — ejecuta setup en $TOP"
SELF=0; [ "$TARGET" = "$SDK_ROOT" ] && SELF=1

STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
backup() {
  local rel="$1" dir="$TARGET/sentinel/.backup/$STAMP"
  mkdir -p "$dir/$(dirname "$rel")" && cp -p "$TARGET/$rel" "$dir/$rel" \
    || die "no se pudo hacer backup de $rel — no se toca nada más"
  note "backup de $rel en sentinel/.backup/$STAMP/"
}

# dist_files → lo que el SDK distribuye (rutas relativas): lo que se copia y lo que tiene que
# poder versionarse
dist_files() {
  (cd "$SDK_ROOT" && find sentinel/README.md sentinel/policy.default.yaml sentinel/hooks sentinel/githooks sentinel/adapters \
     -type f ! -name '.*' ! -name stack.yaml ! -name stack.proposed.yaml | LC_ALL=C sort)
}

echo "Instalando el nivel Guardia en $TARGET"

# ── 1. Enforcement distribuido (se actualiza) ────────────────────────────────────────────
if [ "$SELF" -eq 1 ]; then
  note "instalación sobre el propio SDK: el enforcement ya está en su sitio, no se copia"
else
  updated=0
  while IFS= read -r rel; do
    src="$SDK_ROOT/$rel"; dst="$TARGET/$rel"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
      [ -x "$src" ] && [ ! -x "$dst" ] && { chmod +x "$dst"; updated=$((updated + 1)); }
      continue
    fi
    [ -f "$dst" ] && backup "$rel"
    mkdir -p "$(dirname "$dst")" && cp "$src" "$dst" || die "no se pudo copiar $rel"
    [ -x "$src" ] && chmod +x "$dst"
    updated=$((updated + 1))
  done < <(dist_files)
  [ "$updated" -gt 0 ] && ok "enforcement instalado o actualizado ($updated ficheros en sentinel/)" \
    || ok "enforcement al día"
fi

# ── 2. Lo del consumidor (solo se crea si falta) ─────────────────────────────────────────
# La política del consumidor solo AÑADE reglas: las del SDK (policy.default.yaml) se evalúan
# antes y no se sustituyen (SC-sentinel-guard-17..19, SC-sdk-setup-05). Nivel Método (sdd: true)
# solo si el repo ya trabaja con OpenSpec.
CP="$TARGET/sentinel/policy.yaml"
policy_ids() { sed -nE 's/^[[:space:]]*-[[:space:]]+id:[[:space:]]*([^[:space:]]+).*/\1/p' "$1" | LC_ALL=C sort -u; }
dup=""
if [ -f "$CP" ]; then
  ok "política del consumidor conservada (sentinel/policy.yaml)"
  # Una política anterior a la separación repite las reglas del SDK: el Centinela la rechazaría
  dup="$(LC_ALL=C comm -12 <(policy_ids "$CP") <(policy_ids "$SDK_ROOT/sentinel/policy.default.yaml") | tr '\n' ' ')"
  [ -z "$dup" ] || todo "sentinel/policy.yaml repite reglas del SDK (${dup% }): ahora viven en
    sentinel/policy.default.yaml y el Centinela rechaza los ids duplicados. Deja en policy.yaml
    solo tus reglas propias (es un fichero protegido: lo edita una persona)"
else
  sdd=false; [ -d "$TARGET/openspec" ] && sdd=true
  cat >"$CP" <<EOF || die "no se pudo crear la política del consumidor"
# sentinel/policy.yaml — la política de ESTE proyecto (puesto Centinela).
# Las reglas del SDK viven en sentinel/policy.default.yaml y setup las actualiza. Aquí solo se
# AÑADEN reglas propias (mismo esquema): entre las dos políticas gana la decisión más estricta,
# y un id del SDK repetido es un error de política. Fichero protegido: se cambia en un cambio
# revisado por una persona.
version: 1
sdd: $sdd

rules:
EOF
  ok "política del consumidor creada (sentinel/policy.yaml, sdd: $sdd) — sin reglas propias aún"
fi
[ -f "$TARGET/sentinel/overrides.log" ] || { : >"$TARGET/sentinel/overrides.log" && ok "bitácora creada (sentinel/overrides.log)"; }

# .gitignore: la llave nunca se versiona; los backups tampoco
GI="$TARGET/.gitignore"; gi_added=""
for line in "sentinel/.override" "sentinel/.backup/"; do
  [ -f "$GI" ] && grep -qxF "$line" "$GI" && continue
  [ -f "$GI" ] && [ -z "$gi_added" ] && backup ".gitignore"
  [ -s "$GI" ] && [ -n "$(tail -c1 "$GI")" ] && echo >>"$GI"
  echo "$line" >>"$GI"; gi_added="$gi_added $line"
done
[ -n "$gi_added" ] && ok ".gitignore:$gi_added"

# ── 3. Cableado del Centinela en .claude/settings.json ───────────────────────────────────
# El fragmento es el cableado del propio SDK (su .claude/settings.json, que solo tiene «hooks»):
# una sola fuente, así un cambio de matcher llega a los consumidores al actualizar.
FRAGMENT="$(cat "$SDK_ROOT/.claude/settings.json")"
SCRIPTS='["sentinel/hooks/sentinel-guard.sh","sentinel/hooks/post-edit.sh","sentinel/hooks/session-start.sh"]'
# Fusión segura solo si cada evento es una lista de grupos y cada grupo una lista de hooks
SAFE='type == "object" and ((.hooks // {}) | type == "object")
      and ([ (.hooks // {})[] | type == "array" and all(.[]; type == "object"
               and ((.hooks // []) | type == "array") and all((.hooks // [])[]; type == "object")) ] | all)'
# Las entradas del SDK se reconocen por la ruta de su script (de cualquier versión, con o sin
# comillas): se quitan donde estén, sin tocar los hooks del consumidor de su mismo grupo, y se
# añaden las actuales al final de cada evento
MERGE='def is_sdk: (.command // "") as $c
         | ($c | type) == "string" and ([ $scripts[] as $s | $c | contains($s) ] | any);
       def strip_sdk:
         [ .[] | ((.hooks // []) | length) as $n
               | ([ (.hooks // [])[] | select(is_sdk | not) ]) as $k
               | if $n == ($k | length) then . elif ($k | length) == 0 then empty else .hooks = $k end ];
       .hooks = ((.hooks // {}) | with_entries(.value |= strip_sdk))
       | reduce ($frag.hooks | to_entries[]) as $e (.; .hooks[$e.key] = ((.hooks[$e.key] // []) + $e.value))'

# jq: el de SENTINEL_SETUP_JQ o el del PATH, nunca uno que viva dentro del repo destino (el
# agente podría poner ahí uno que «fusione» quitando el cableado)
JQ_BIN="$(command -v "$JQ" 2>/dev/null || true)"
if [ -n "$JQ_BIN" ]; then
  jq_dir="$(cd "$(dirname "$JQ_BIN")" 2>/dev/null && pwd -P)"
  case "$jq_dir/" in
    "$TARGET"/*) note "se ignora el jq de $JQ_BIN: está dentro del repo destino"; JQ_BIN="" ;;
  esac
fi

S="$TARGET/.claude/settings.json"; F="$TARGET/sentinel/settings.fragment.json"
write_fragment() {
  [ -f "$F" ] && [ "$(cat "$F")" = "$FRAGMENT" ] || printf '%s\n' "$FRAGMENT" >"$F"
  todo "$1 — .claude/settings.json no se ha tocado. Añade a mano las entradas de
    sentinel/settings.fragment.json dentro de \"hooks\" (o instala jq) y vuelve a ejecutar setup"
}
# El paso manual ya está hecho: el fragmento sobra (y no debe acabar versionado)
drop_fragment() { [ -f "$F" ] && rm -f "$F" && note "retirado sentinel/settings.fragment.json: el cableado ya está"; return 0; }
# wired_ok <fichero> → comprobación por texto, sin jq: cada script del SDK aparece una sola vez y
# están los matchers actuales del fragmento
wired_ok() {
  local s m
  for s in sentinel-guard post-edit session-start; do
    [ "$(grep -o "sentinel/hooks/$s\.sh" "$1" 2>/dev/null | wc -l | tr -d ' ')" = 1 ] || return 1
  done
  while IFS= read -r m; do
    [ -z "$m" ] || grep -qF "\"$m\"" "$1" || return 1
  done <<EOF
$(printf '%s\n' "$FRAGMENT" | sed -nE 's/.*"matcher"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
EOF
}
# merged_ok <json> → el resultado de una fusión es un objeto JSON y conserva el cableado
merged_ok() {
  local t rc
  case "$1" in "{"*) ;; *) return 1 ;; esac
  t="$(mktemp)" || return 1
  printf '%s\n' "$1" >"$t"; wired_ok "$t"; rc=$?
  rm -f "$t"; return $rc
}
if [ ! -f "$S" ]; then
  mkdir -p "$TARGET/.claude" && printf '%s\n' "$FRAGMENT" >"$S" || die "no se pudo crear .claude/settings.json"
  ok "Centinela cableado (.claude/settings.json creado)"; drop_fragment
elif [ -z "$JQ_BIN" ]; then
  if wired_ok "$S"; then
    ok "Centinela ya cableado en .claude/settings.json (sin jq: comprobado por texto)"; drop_fragment
  else
    write_fragment "jq no está disponible y ya hay un .claude/settings.json"
  fi
elif ! "$JQ_BIN" -e "$SAFE" "$S" >/dev/null 2>&1; then
  write_fragment ".claude/settings.json no es JSON válido o tiene una forma inesperada: fusionar no es seguro"
elif ! merged="$("$JQ_BIN" --argjson frag "$FRAGMENT" --argjson scripts "$SCRIPTS" "$MERGE" "$S" 2>/dev/null)"; then
  write_fragment "jq no pudo fusionar .claude/settings.json"
elif ! merged_ok "$merged"; then
  # Lo que se va a escribir tiene que conservar el cableado: se comprueba en bash, sin fiarse de jq
  write_fragment "el resultado de la fusión no conserva el cableado del Centinela"
else
  if [ "$("$JQ_BIN" -S . "$S")" = "$(printf '%s' "$merged" | "$JQ_BIN" -S .)" ]; then
    ok "Centinela ya cableado en .claude/settings.json"; drop_fragment
  else
    backup ".claude/settings.json"
    printf '%s\n' "$merged" >"$S" || die "no se pudo escribir .claude/settings.json"
    ok "Centinela cableado en .claude/settings.json: entradas del SDK al día, lo tuyo se conserva"
    drop_fragment
  fi
fi

# ── 4. La Esclusa: core.hooksPath, o encadenada en los git hooks que ya hay ──────────────
# abs_dir <dir> → <dir> absoluto; uno relativo se resuelve, como hace git, desde la raíz del repo
abs_dir() { case "$1" in /*) printf '%s' "${1%/}" ;; *) printf '%s' "$TARGET/${1%/}" ;; esac; }
# own_hooks <dir> → « hook1 hook2…» ejecutables de <dir> (los .sample no cuentan)
own_hooks() {
  local d h list=""
  d="$(abs_dir "$1")"
  for h in "$d"/*; do
    [ -f "$h" ] && [ -x "$h" ] && case "$h" in *.sample) ;; *) list="$list $(basename "$h")" ;; esac
  done
  printf '%s' "$list"
}
# is_esclusa <hooksPath> → apunta a la Esclusa de este repo, se escriba como se escriba
is_esclusa() {
  local p="${1%/}"; p="${p#./}"
  [ "$p" = "$HOOKS_PATH" ] && return 0
  case "$p" in /*) [ -d "$p" ] && [ "$(cd "$p" && pwd -P)" = "$TARGET/$HOOKS_PATH" ] ;; *) return 1 ;; esac
}
# chain_todo <situación> <dir de los hooks> → pendiente con las líneas de chain.sh para cada hook
chain_todo() {
  local h lines=""
  for h in commit-msg pre-commit pre-push; do
    lines="$lines
    ── $2/$h (créalo ejecutable si no existe):
$(chain_snippet "$h" | sed 's/^/      /')"
  done
  todo "$1
    Encadena la Esclusa: pon estas líneas al principio de cada hook (tras el shebang). Así un
    exit del hook no se las salta, el resto del pre-push sigue recibiendo las refs y, en un repo
    sin la Esclusa, no hacen nada. Después vuelve a ejecutar setup.$lines"
}

cur="$(git -C "$TARGET" config --get core.hooksPath || true)"
if [ -n "$cur" ] && is_esclusa "$cur"; then
  ok "Esclusa activa (core.hooksPath → $cur)"
elif [ -n "$cur" ]; then
  # Puede venir del config global de la persona (p. ej. un escáner corporativo): tampoco se pisa
  origin="$(git -C "$TARGET" config --show-origin --get core.hooksPath 2>/dev/null | cut -f1)"
  cur_dir="$(git -C "$TARGET" config --type=path --get core.hooksPath 2>/dev/null || printf '%s' "$cur")"
  cur_dir="${cur_dir%/}"
  scope=""
  [ -n "$(git -C "$TARGET" config --local --get core.hooksPath 2>/dev/null)" ] \
    || scope=" Ese core.hooksPath no es de este repo: vale para todos tus repos."
  case "$cur_dir" in
    .husky/_|*/.husky/_)
      # husky v9: .husky/_ son envoltorios generados (e ignorados por git) que ejecutan .husky/<hook>
      hsrc="${cur_dir%/_}"
      if chain_done "$(abs_dir "$hsrc")"; then
        ok "Esclusa encadenada en husky ($hsrc/commit-msg, pre-commit y pre-push)"
      else
        chain_todo "el repo usa husky (core.hooksPath → «${cur}»). Los envoltorios de «${cur}» los
    genera husky y git los ignora: los hooks están en $hsrc/<hook>, y ahí va la Esclusa. setup
    no cambia core.hooksPath." "$hsrc"
      fi ;;
    *)
      if [ -z "$(own_hooks "$cur_dir")" ]; then
        # Un hooksPath global y relativo (p. ej. «.githooks») sin esa carpeta aquí no ejecuta nada
        todo "core.hooksPath → «${cur}» (definido en ${origin:-config de git}) no tiene hooks en este repo:
    hoy no ejecuta nada aquí, así que activar la Esclusa no silencia nada. setup no cambia
    configuración de git que no es suya; actívala tú (solo afecta a este repo):
    git config core.hooksPath $HOOKS_PATH"
      elif chain_done "$(abs_dir "$cur_dir")" exec; then
        ok "Esclusa encadenada en los hooks de «${cur}»"
      elif git -C "$TARGET" check-ignore -q -- "$cur_dir/pre-commit" 2>/dev/null; then
        chain_todo "core.hooksPath → «${cur}» está ignorado por git: lo genera una herramienta y lo que
    pongas ahí se perderá. Pon las líneas en los hooks fuente de esa herramienta, no en «${cur}»." "<hooks fuente>"
      else
        chain_todo "el repo ya usa core.hooksPath → «${cur}» (definido en ${origin:-config de git}); no se
    cambia para no silenciar esos hooks.${scope} Si en este repo no los necesitas, la
    alternativa es activar la Esclusa solo aquí: git config core.hooksPath $HOOKS_PATH" "$cur"
      fi ;;
  esac
else
  hd="$(git -C "$TARGET" rev-parse --git-path hooks)"
  own="$(own_hooks "$hd")"
  if [ -z "$own" ]; then
    git -C "$TARGET" config core.hooksPath "$HOOKS_PATH" || die "no se pudo configurar core.hooksPath"
    ok "Esclusa activada (core.hooksPath → $HOOKS_PATH)"
  elif chain_done "$(abs_dir "$hd")" exec; then
    ok "Esclusa encadenada en los hooks de $hd (core.hooksPath no se activa: los silenciaría)"
  else
    chain_todo "hay git hooks propios en $hd:$own. Activar core.hooksPath los dejaría sin
    ejecutarse, así que no se activa: la Esclusa se encadena en ellos, donde están." "$hd"
  fi
fi

# ── 5. Adaptador de stack: se propone, nunca se aplica solo ──────────────────────────────
A="$TARGET/sentinel/adapters"
if [ -f "$A/stack.yaml" ]; then
  ok "adaptador de stack declarado (sentinel/adapters/stack.yaml)"
else
  # shellcheck source=/dev/null
  source "$SDK_ROOT/sentinel/adapters/stack.sh"
  if proposal="$(stack_detect "$TARGET" 2>/dev/null)"; then
    if ! { [ -f "$A/stack.proposed.yaml" ] && [ "$(cat "$A/stack.proposed.yaml")" = "$proposal" ]; }; then
      # Una propuesta que la persona ya revisó no se pierde
      [ -f "$A/stack.proposed.yaml" ] && backup "sentinel/adapters/stack.proposed.yaml"
      printf '%s\n' "$proposal" >"$A/stack.proposed.yaml"
    fi
    note "stack detectado: propuesta en sentinel/adapters/stack.proposed.yaml. Revísala y
    renómbrala a stack.yaml para que la Esclusa ejecute format, lint y tests"
  else
    note "stack no reconocido (Node o Laravel): sin sentinel/adapters/stack.yaml la Esclusa omite
    format, lint y tests con aviso. Escríbelo a mano (formato en sentinel/adapters/stack.sh)"
  fi
fi

# ── 6. Herramientas obligatorias: se avisa ahora, no en el primer commit ─────────────────
if command -v "$GITLEAKS" >/dev/null 2>&1; then
  ok "gitleaks disponible"
else
  todo "gitleaks no está instalado y es obligatorio: la Esclusa rechazará todos los commits.
    macOS: brew install gitleaks · Windows: scoop install gitleaks · Linux: binario de
    https://github.com/gitleaks/gitleaks/releases (comprueba con: gitleaks version)"
fi

# ── 7. Lo que tiene que viajar con el repo no puede estar ignorado ───────────────────────
# Todo lo que se instala (no una muestra: la librería de la Esclusa también) y lo del consumidor
versioned() {
  dist_files
  printf '%s\n' sentinel/policy.yaml sentinel/overrides.log .claude/settings.json
  [ ! -f "$TARGET/sentinel/adapters/stack.yaml" ] || echo sentinel/adapters/stack.yaml
}
# exception_for <fichero> → las líneas que lo reincluyen desde el .gitignore del repo (que manda
# sobre core.excludesFile). Si se ignora una carpeta que lo contiene, git no mira dentro: hay que
# reincluir la carpeta. De .claude/, solo settings.json: lo demás suele ser local de cada persona.
exception_for() {
  local f="$1" d top=""
  case "$f" in .claude/settings.json) printf '%s\n' '!.claude/' '.claude/*' '!.claude/settings.json'; return 0 ;; esac
  d="$(dirname "$f")"
  while [ "$d" != "." ]; do
    git -C "$TARGET" check-ignore -q -- "$d/" 2>/dev/null && top="$d"
    d="$(dirname "$d")"
  done
  if [ -n "$top" ]; then printf '!%s/\n' "$top"; else printf '!%s\n' "$f"; fi
}
ignored=""; exceptions=""
while IFS= read -r f; do
  # -q decide (una excepción «!…» también aparece en -v, pero no ignora); -v solo dice qué regla
  git -C "$TARGET" check-ignore -q -- "$f" 2>/dev/null || continue
  why="$(git -C "$TARGET" check-ignore -v -- "$f" 2>/dev/null | cut -f1)"
  rest="${why#*:}"
  ignored="$ignored
      $f — lo ignora «${rest#*:}» (${why%%:*}, línea ${rest%%:*})"
  exceptions="$exceptions
$(exception_for "$f")"
done < <(versioned)
if [ -n "$ignored" ]; then
  exceptions="$(printf '%s\n' "$exceptions" | awk 'NF && !seen[$0]++' | sed 's/^/      /')"
  todo "el .gitignore deja fuera ficheros que hay que versionar:$ignored
    Sin ellos en git, tus compañeros no reciben el Centinela o la Esclusa, o la bitácora se queda
    en tu máquina. Añade al final del .gitignore del repo (vale aunque la regla venga de fuera,
    p. ej. de core.excludesFile):
$exceptions
    Compruébalo con: git check-ignore -v <fichero>"
fi

# Con core.fileMode=false git no guarda el permiso de ejecución: en los clones ignoraría los hooks
if [ "$(git -C "$TARGET" config --bool core.fileMode 2>/dev/null)" = "false" ]; then
  noexec=""
  while IFS= read -r f; do
    [ -x "$SDK_ROOT/$f" ] || continue
    [ "$(git -C "$TARGET" ls-files -s -- "$f" | cut -d' ' -f1)" = 100755 ] || noexec="$noexec $f"
  done < <(dist_files)
  [ -z "$noexec" ] || todo "este repo tiene core.fileMode=false: git no guarda el permiso de ejecución
    y en los clones ignora los hooks que no lo tienen (la Esclusa no correría). Después del git
    add, márcalos como ejecutables en el índice:
    git add --chmod=+x$noexec"
fi

# ── 8. El Centinela instalado tiene que dejar pasar lo inocuo ────────────────────────────
# (con ids duplicados ya hay un pendiente que explica el bloqueo)
if [ -z "$dup" ]; then
  smoke_err="$(cd "$TARGET" && printf '%s' '{"tool_name":"Bash","tool_input":{"command":"true"}}' \
    | env -u SENTINEL_POLICY -u SENTINEL_POLICY_DEFAULT -u SENTINEL_OVERRIDE -u SENTINEL_CONFIRM \
        CLAUDE_PROJECT_DIR="$TARGET" bash "$TARGET/sentinel/hooks/sentinel-guard.sh" 2>&1 >/dev/null)" \
    || todo "el Centinela instalado deniega una acción inocua (\`true\`): ${smoke_err#sentinel-guard: }
    Mientras siga así, el agente no podrá hacer nada en este repo. Revisa sentinel/policy.yaml"
fi

echo
if [ "$pending" -eq 1 ]; then
  echo "Nivel Guardia instalado con pasos pendientes (⚠ arriba). Vuelve a ejecutar setup al resolverlos."
  exit 3
fi
echo "✓ Nivel Guardia instalado. Versiona sentinel/, .claude/settings.json y .gitignore en un commit."
exit 0
