# Proposal — hook-coexistence (la Esclusa convive con otros gestores de git hooks)

> Nace de la segunda revisión adversarial de `git-gates` (tema 4,
> [`../archive/2026-10-20-git-gates/review/round2/README.md`](../archive/2026-10-20-git-gates/review/round2/README.md)). La persona
> decidió el 2026-10-16 sacarlo de esa PR: no es un fallo puntual, sino una decisión de diseño.

## Why

`git-gates` instala la Esclusa con `core.hooksPath` y, si el repo ya usa otros git hooks, da
unas líneas para encadenarla **dentro** de esos hooks. Funciona con hooks escritos a mano, pero
cada gestor de hooks tiene su propio ciclo de vida, y la segunda revisión lo reprodujo con las
herramientas reales:

- **lefthook y el framework pre-commit** regeneran `.git/hooks` (al cambiar su configuración o
  en cada `npm install`/`pre-commit install`) y las líneas de la Esclusa se pierden sin aviso
  (P2-2).
- **husky** instala sus hooks también en CI: la Esclusa encadenada rompe los commits y pushes
  de release (P2-5). Su interruptor `HUSKY=0` (y su `init.sh`) la apagan (V2-3). Antes del
  primer `npm install`, `setup` activa `core.hooksPath` y husky lo pisa después (P2-4).
- **git-lfs**: en el clon de un compañero, `session-start` propone activar `core.hooksPath`,
  y hacerlo deja mudos los hooks de LFS (P2-3). Además el aviso se dirige al agente con un
  comando que el Centinela le bloquea (V2-7) y no comprueba que el hook encadenado sea
  ejecutable (A2-4).
- **Versionado del encadenado**: el mensaje final de `setup` no nombra los hooks de husky que
  hay que versionar (P2-8).

En `git-gates`, los hooks encadenados de husky (`.husky/<hook>`) y de `.git/hooks/` ya están
protegidos frente al agente (`self-protection`); los de un `core.hooksPath` propio con otra ruta
no lo están (A3-5 de la tercera revisión). La guía y `sentinel/README.md` documentan el límite.
También pertenece a este cambio que `setup` acepte con exit 0 un encadenado en una ubicación
que no está protegida.

## What Changes

Diseñar (gate **Diseño**) cómo convive la Esclusa con cada gestor, eligiendo entre dos enfoques
o una mezcla:

1. **Encadenar la Esclusa en los hooks fuente de cada herramienta** (lo de hoy, extendido):
   `.husky/<hook>`, un comando en `lefthook.yml`, un hook `repo: local` en
   `.pre-commit-config.yaml`. Sobrevive a la regeneración y viaja con el repo.
2. **Invertir el encadenado**: `core.hooksPath` siempre a la Esclusa, que llama después a los
   hooks del consumidor. Los interruptores de cada herramienta solo apagan lo suyo, pero hay
   que reenviar todos los hooks que usen (git-lfs usa también `post-checkout`, `post-merge`…)
   y pre-commit se niega a instalarse con `core.hooksPath` puesto.

Más: el aviso de `session-start` dirigido a la persona y sin romper LFS, la comprobación de que
el hook encadenado es ejecutable, el comportamiento en CI y el mensaje final de `setup`.

## Impact

- Capability afectada: `sdk-setup` (y el aviso de `session-start` en `sentinel-guard`).
- Ficheros: `ai-specs/skills/setup/` y `sentinel/hooks/session-start.sh` (protegidos: los
  aplica una persona o con la llave).
- El banco gana casos con estructuras reales de husky v9, lefthook, pre-commit y git-lfs.
