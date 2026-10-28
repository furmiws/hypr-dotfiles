#!/bin/bash
pgrep -x wofi >/dev/null && { pkill -x wofi; exit; }
choice=$(printf "󰐥  Shutdown\n󰜉  Reboot\n󰤄  Suspend\n󰍃  Log out\n" \
  | wofi --dmenu --hide-search --prompt Power --location 5 --xoffset -10 --width 240 --height 200)
case "$choice" in
  *Shutdown*) systemctl poweroff ;;
  *Reboot*) systemctl reboot ;;
  *Suspend*) systemctl suspend ;;
  *"Log out"*) loginctl terminate-user "$USER" ;;
esac
