#!/usr/bin/env bash
pgrep -x fuzzel >/dev/null && { pkill -x fuzzel; exit; }
bat=$(cat /sys/class/power_supply/BAT*/capacity | head -n1)
st=$(cat /sys/class/power_supply/BAT*/status | head -n1)
cur=$(powerprofilesctl get)
mark() { [ "$cur" = "$1" ] && echo "● $2" || echo "○ $2"; }
choice=$(printf "󰁹  Battery: %s%% (%s)\n%s\n%s\n%s\n" "$bat" "$st" \
  "$(mark power-saver 'Power saver')" "$(mark balanced 'Balanced')" "$(mark performance 'Performance')" \
  | $HOME/.config/waybar/dmenu.sh --dmenu --hide-search --prompt Battery --location 5 --xoffset -10 --width 280 --height 200)
case "$choice" in
  *"Power saver"*) powerprofilesctl set power-saver ;;
  *Balanced*) powerprofilesctl set balanced ;;
  *Performance*) powerprofilesctl set performance ;;
esac
