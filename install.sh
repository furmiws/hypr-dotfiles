#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HOME/.config"
STAMP="$(date +%Y%m%d-%H%M%S)"

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

command -v pacman >/dev/null || { echo "This installer is for Arch-based systems (pacman)."; exit 1; }
[ "$EUID" -eq 0 ] && { echo "Run this as your normal user, not root."; exit 1; }

say "Installing packages"
sudo pacman -S --needed --noconfirm waybar playerctl ttf-jetbrains-mono-nerd kitty wofi fuzzel mako \
  libnotify power-profiles-daemon bluez bluez-utils blueman networkmanager btop udisks2 \
  fastfetch python git base-devel

say "Waybar workspace-click fix"
if pacman -Q waybar-git >/dev/null 2>&1; then
  echo "waybar-git is already installed."
else
  read -rp "Install waybar-git from the AUR (fixes workspace clicking on Hyprland 0.55 Lua)? [Y/n] " ans
  if [[ ! "$ans" =~ ^[Nn]$ ]]; then
    if command -v yay >/dev/null 2>&1; then
      yay -S --needed waybar-git
    elif command -v paru >/dev/null 2>&1; then
      paru -S --needed waybar-git
    else
      tmp="$(mktemp -d)"
      git clone https://aur.archlinux.org/waybar-git.git "$tmp/waybar-git"
      (cd "$tmp/waybar-git" && makepkg -si)
      rm -rf "$tmp"
    fi
  fi
fi

say "Enabling services"
sudo systemctl enable --now bluetooth power-profiles-daemon || true
systemctl is-enabled NetworkManager >/dev/null 2>&1 || sudo systemctl enable --now NetworkManager || true

say "Copying configs (old ones are backed up as *.bak-$STAMP)"
mkdir -p "$CFG"
for d in waybar wofi fastfetch fuzzel mako; do
  if [ -e "$CFG/$d" ]; then
    mv "$CFG/$d" "$CFG/$d.bak-$STAMP"
    echo "Backed up old $d"
  fi
  cp -r "$DIR/config/$d" "$CFG/$d"
done
chmod +x "$CFG"/waybar/*.sh "$CFG"/waybar/*.py
sed -i "s#\"source\": \".*\"#\"source\": \"$HOME/.config/fastfetch/logo.png\"#" "$CFG/fastfetch/config.jsonc"

if ! ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
  say "No battery found, removing the battery module"
  python3 -c 'import json,sys; p=sys.argv[1]; c=json.load(open(p)); c["modules-right"]=[m for m in c["modules-right"] if m!="battery"]; json.dump(c,open(p,"w"),indent=4)' "$CFG/waybar/config.jsonc"
fi

say "Hyprland config"
LUA="$CFG/hypr/hyprland.lua"
move="830 810"
if command -v hyprctl >/dev/null 2>&1 && out="$(hyprctl monitors -j 2>/dev/null)" && [ -n "$out" ]; then
  move="$(python3 -c 'import json,sys; m=json.load(sys.stdin)[0]; print((m["width"]-260)//2, m["height"]-270)' <<<"$out" 2>/dev/null)" || move="830 810"
fi

if [ ! -f "$LUA" ]; then
  echo "No $LUA found. You need Hyprland 0.55+ with a Lua config."
  echo "Add the contents of hypr/setup-block.lua to your config by hand."
elif grep -q ">>> dotfiles-setup >>>" "$LUA"; then
  echo "Already added, skipping."
else
  cp "$LUA" "$LUA.bak-$STAMP"
  { echo; sed "s/move *= *\"[0-9]* [0-9]*\"/move  = \"$move\"/" "$DIR/hypr/setup-block.lua"; } >> "$LUA"
  echo "Added the setup block (clock popup position: $move)."
  hyprctl reload >/dev/null 2>&1 || true
fi

say "Done!"
echo "Log out and back in (or run: waybar &) to see the bar."
echo "Open the app launcher with SUPER + D, and try: fastfetch"
