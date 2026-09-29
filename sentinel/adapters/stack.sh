#!/usr/bin/env bash
# stack.sh — lector del adaptador de stack (sentinel/adapters/stack.yaml del consumidor).
# Se usa con `source`. Lo consumen la Esclusa (githooks), la Aduana (CI) y el Centinela
# (post-edit) sin conocer el stack. Bash puro, sin dependencias.
#
# Formato de stack.yaml — plano, una clave por línea; `#` comenta solo al principio de línea
# (al final de una línea es parte del comando):
#   format:        formatea en sitio        (recibe los ficheros)
#   format-check:  comprueba formato        (recibe los ficheros en staging)
#   lint:          lint                      (recibe los ficheros en staging)
#   static:        análisis estático         (sin argumentos)
#   tests:         suite de tests            (sin argumentos)
#   env-ready:     ¿el entorno está listo?  (sin argumentos; exit ≠ 0 = entorno roto)
#   env-fix:       texto con la instrucción que se muestra si env-ready falla (opcional)
# Falsifica: SC-git-gates-07 (fixture/githooks/cases/sc-07-stack-adapter.sh).

# stack_file → ruta del adaptador: $SENTINEL_STACK, o sentinel/adapters/stack.yaml en la raíz
# del repo (se encuentra desde cualquier subdirectorio)
stack_file() {
  if [ -n "${SENTINEL_STACK:-}" ]; then printf '%s\n' "$SENTINEL_STACK"; return; fi
  local root; root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  printf '%s\n' "$root/sentinel/adapters/stack.yaml"
}

stack_available() { [ -f "$(stack_file)" ]; }

# stack_get <clave> → el comando declarado, sin comillas envolventes; vacío si no hay
stack_get() {
  local f; f="$(stack_file)"
  [ -f "$f" ] || return 0
  sed -nE "s/^$1:[[:space:]]*//p" "$f" | head -1 \
    | sed -E -e 's/[[:space:]]+$//' -e "s/^\"(.*)\"$/\1/" -e "s/^'(.*)'$/\1/"
}

# stack_detect <dir> → imprime un stack.yaml propuesto para Node o Laravel. Nunca escribe
# nada: lo usa `setup` para proponer, y la persona decide. Stack desconocido → exit 1.
stack_detect() {
  local d="${1:-.}"
  if [ -f "$d/artisan" ] && [ -f "$d/composer.json" ]; then
    echo "# stack.yaml — propuesto por stack_detect (Laravel). Revísalo antes de confiar en él."
    echo "tests: php artisan test"
    if [ -f "$d/vendor/bin/pint" ]; then
      echo "format: vendor/bin/pint"
      echo "format-check: vendor/bin/pint --test"
    fi
    if [ -f "$d/phpstan.neon" ] || [ -f "$d/phpstan.neon.dist" ]; then
      echo "static: vendor/bin/phpstan analyse"
    fi
    echo "# env-ready: declara cómo saber que tu entorno está listo (p. ej. el contenedor de Sail)"
    return 0
  fi
  if [ -f "$d/package.json" ]; then
    # Detección por nombre de script (sin jq): solo se propone lo que existe
    _has_script() { grep -Eq "\"$1\"[[:space:]]*:" "$d/package.json"; }
    echo "# stack.yaml — propuesto por stack_detect (Node). Revísalo antes de confiar en él."
    _has_script test         && echo "tests: npm test"
    _has_script lint         && echo "lint: npm run -s lint --"
    _has_script format       && echo "format: npm run -s format --"
    _has_script 'format:check' && echo "format-check: npm run -s format:check --"
    _has_script typecheck    && echo "static: npm run -s typecheck"
    echo "# env-ready: declara cómo saber que tu entorno está listo (si depende de servicios)"
    return 0
  fi
  echo "stack_detect: stack no reconocido en $d (Node o Laravel) — escribe stack.yaml a mano" >&2
  return 1
}
