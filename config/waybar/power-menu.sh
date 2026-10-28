#!/usr/bin/env bash
pgrep -x fuzzel >/dev/null && { pkill -x fuzzel; exit; }
choice=$(printf "󰐥  Shutdown\n󰜉  Reboot\n󰤄  Suspend\n󰍃  Log out\n" \
  | $HOME/.config/waybar/dmenu.sh --dmenu --hide-search --prompt Power --location 5 --xoffset -10 --width 240 --height 200)
case "$choice" in
  *Shutdown*) systemctl poweroff ;;
  *Reboot*) systemctl reboot ;;
  *Suspend*) systemctl suspend ;;
  *"Log out"*) loginctl terminate-user "$USER" ;;
esac
