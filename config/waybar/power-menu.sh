#!/usr/bin/env bash
pgrep -x fuzzel >/dev/null && { pkill -x fuzzel; exit; }
choice=$(printf 'Lock\nSuspend\nLog out\nReboot\nShutdown\n' \
  | "$HOME/.config/waybar/dmenu.sh" --dmenu --prompt Power --xoffset -10 --width 240 --height 200)
case "$choice" in
  Lock)       pidof hyprlock || hyprlock ;;
  Suspend)    systemctl suspend ;;
  "Log out")  loginctl terminate-user "$USER" ;;
  Reboot)     systemctl reboot ;;
  Shutdown)   systemctl poweroff ;;
esac
