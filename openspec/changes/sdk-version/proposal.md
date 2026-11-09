# Proposal — sdk-version (qué versión del SDK está instalada, y no retroceder sin querer)

> Nace de la tercera revisión adversarial de `git-gates` (P3-4,
> [`../archive/2026-10-20-git-gates/review/round3/README.md`](../archive/2026-10-20-git-gates/review/round3/README.md)). La persona
> decidió el 2026-10-17 sacarlo de esa PR a su propio cambio.

## Why

`setup` instala lo que haya en la copia del SDK desde la que se ejecuta, sin saber qué versión
había instalada en el repo. La revisión lo reprodujo: un compañero con un clon del SDK tres
commits más viejo, al que `session-start` le dice «ejecuta setup», revierte el enforcement en
silencio (la regla `protect-installer` y la de «gana la más estricta» desaparecen) y `setup` le
invita a commitearlo con «✓ Nivel Guardia instalado». En el repo nada dice qué versión del SDK
está instalada, así que la bajada solo se ve leyendo el diff de `sentinel/`.

## What Changes

1. `setup` escribe un fichero versionado, `sentinel/.sdk-version`, con la versión del SDK que
   instala: el commit de la copia del SDK y si su árbol tenía cambios sin commitear.
2. Antes de sustituir lo distribuido, `setup` compara esa versión con la de la copia desde la
   que se ejecuta. Solo instala sin más si el commit instalado es antecesor del de la copia (o
   el mismo) y la copia no tiene cambios sin commitear. En cualquier otro caso no escribe nada,
   dice qué versión hay y cuál instalaría, y sale con error; la persona lo confirma con
   `--downgrade` en el comando.
3. `sentinel/.sdk-version` es un fichero protegido, como el resto del enforcement.
4. `setup --activate` activa la Esclusa en un clon que ya tiene la instalación versionada, sin
   copiar nada. En ese clon, `session-start` propone `setup --activate`, no reinstalar.

## Decisiones

Gate **Intención** aprobado el 2026-11-08. La persona eligió:

1. **La versión es el commit, y se compara por ascendencia.** El SDK no tiene tags. Se
   registra el commit de la copia del SDK y si su árbol estaba sucio. Una copia es «igual o más
   nueva» solo si el commit instalado es antecesor del suyo; si no lo es, si la copia no es un
   clon de git o si el fichero de versión no se puede leer, cuenta como dudosa.
2. **Se confirma con una opción en el comando, `--downgrade`.** Sin ella, `setup` no toca nada
   ante una versión más vieja, dudosa o con cambios sin commitear. La opción va en el comando
   que la persona ve y aprueba, también cuando lo lanza el agente, que no tiene terminal
   interactivo.
3. **`sentinel/.sdk-version` está protegido** (`self-protection`): el agente no lo reescribe
   para que una versión vieja parezca la misma.
4. **Un modo `setup --activate`.** Comprueba que la instalación versionada está completa y
   activa la Esclusa (o da las líneas para encadenarla, como `setup`), sin copiar nada.

## Impact

- Capabilities afectadas: `sdk-setup` (la versión, `--downgrade`, `--activate` y el aviso de
  arranque) y `sentinel-guard` (el fichero de versión, protegido).
- Ficheros protegidos (los aplica una persona con un parche): `ai-specs/skills/setup/setup.sh`,
  `sentinel/hooks/session-start.sh` y `sentinel/policy.default.yaml`.
- El banco gana casos con una copia del SDK más vieja, una dudosa, una con cambios sin
  commitear, `--downgrade`, `--activate` y el aviso en un clon con la instalación versionada.
- La guía (`docs/guia-uso.md`, instalar y el clon de un compañero).
- Límite: la comprobación solo protege entre versiones que la incluyen. Una copia del SDK
  anterior a este cambio no sabe leer `sentinel/.sdk-version` y sigue instalando sin
  comprobar; lo hará visible el fichero, que esa copia no actualiza.
