#!/usr/bin/env bash
# SC-sentinel-paths-04: lo que solo se parece a la configuración de git no se bloquea (un nombre
#   que la contiene, un .gitconfig que no es el de la persona); la de la persona sí, también
#   cuando ~/.gitconfig es un enlace hacia un repo de dotfiles.
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"
P="$DEFAULT_POLICY"
trap cleanup_workspace EXIT

esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
write_payload() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$(esc "$1")"; }

mk_workspace
H="$WS/casa"                                   # la carpeta personal de la prueba
mkdir -p "$H/.config/git" "$WS/dotfiles" "$WS/docs" "$WS/otros"
: >"$WS/dotfiles/.gitconfig"; : >"$WS/otros/.gitconfig"
ln -s "$WS/dotfiles/.gitconfig" "$H/.gitconfig"   # ~/.gitconfig → dotfiles/.gitconfig
guard() { RH_CWD="$WS" run_hook "$GUARD_HOOK" "$1" HOME="$H" SENTINEL_POLICY_DEFAULT="$P" SENTINEL_POLICY="$CONSUMER_POLICY"; }

# Pasan: solo se parecen
for f in docs/.gitconfig.example .git/config.bak .git/configs/x otros/.gitconfig \
         /Users/me/proyecto/.gitconfig.example; do
  guard "$(write_payload "$f")"
  assert_exit 0 || { echo "    debería permitirse: $f" >&2; exit 1; }
done

# Se bloquean: la configuración de git de la persona, por cualquier ruta, y la del repo
for f in "$H/.gitconfig" "$H/.config/git/config" dotfiles/.gitconfig "$WS/dotfiles/.gitconfig" \
         /Users/me/.gitconfig /home/me/.config/git/config .git/config .git/config.worktree; do
  guard "$(write_payload "$f")"
  assert_exit 2 || { echo "    debería bloquearse: $f" >&2; exit 1; }
done
exit 0
