#!/bin/bash
pgrep -x fuzzel >/dev/null && { pkill -x fuzzel; exit; }

XOFF=-385
menu() { $HOME/.config/waybar/dmenu.sh --dmenu --hide-search --location 5 --xoffset "$XOFF" --width 320 --height 380 --prompt "$1"; }
msg() { printf '%s\n' "$1" | $HOME/.config/waybar/dmenu.sh --dmenu --hide-search --location 5 --xoffset "$XOFF" --width 320 --height 90 --prompt Wi-Fi >/dev/null; }

# Wi-Fi is off: only offer to turn it on
if [ "$(nmcli radio wifi)" != "enabled" ]; then
  choice=$(printf 'Turn Wi-Fi on\n' | menu Wi-Fi)
  [ -n "$choice" ] && nmcli radio wifi on
  exit
fi

nmcli dev wifi rescan >/dev/null 2>&1 &

declare -A map seen open
active=""
lines=""
while IFS=: read -r inuse signal sec ssid; do
  [ -z "$ssid" ] && continue
  [ -n "${seen[$ssid]}" ] && continue
  seen[$ssid]=1
  if   [ "$signal" -ge 75 ]; then bars="▂▄▆█"
  elif [ "$signal" -ge 50 ]; then bars="▂▄▆ "
  elif [ "$signal" -ge 25 ]; then bars="▂▄  "
  else bars="▂   "; fi
  mark="  "
  if [ "$inuse" = "*" ]; then mark="● "; active="$ssid"; fi
  extra=""
  if [ -z "$sec" ] || [ "$sec" = "--" ]; then extra="  (open)"; open[$ssid]=1; fi
  line="${mark}${bars}  ${ssid}${extra}"
  map[$line]=$ssid
  lines+="$line"$'\n'
done < <(nmcli -t -e no -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan no)

choice=$( { printf 'Turn Wi-Fi off\nScan for networks\n'; printf '%s' "$lines"; } | menu Wi-Fi )
[ -z "$choice" ] && exit

case "$choice" in
  "Turn Wi-Fi off") nmcli radio wifi off; exit ;;
  "Scan for networks")
    nmcli dev wifi rescan >/dev/null 2>&1
    printf 'Scanning for networks...\n' | timeout 3 $HOME/.config/waybar/dmenu.sh --dmenu --hide-search --location 5 --xoffset "$XOFF" --width 320 --height 90 >/dev/null
    exec "$0" ;;
esac

ssid=${map[$choice]}
[ -z "$ssid" ] && exit

# clicking the connected network disconnects it
if [ "$ssid" = "$active" ]; then
  nmcli connection down id "$ssid" >/dev/null 2>&1
  exit
fi

# already saved: connect directly
if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
  nmcli connection up id "$ssid" >/dev/null 2>&1 || msg "Could not connect to $ssid"
  exit
fi

# open network
if [ -n "${open[$ssid]}" ]; then
  nmcli dev wifi connect "$ssid" >/dev/null 2>&1 || msg "Could not connect to $ssid"
  exit
fi

# new secured network: ask for the password
pass=$($HOME/.config/waybar/dmenu.sh --dmenu --password --location 5 --xoffset "$XOFF" --width 320 --height 80 --prompt "Password for $ssid" </dev/null)
[ -z "$pass" ] && exit
if ! nmcli dev wifi connect "$ssid" password "$pass" >/dev/null 2>&1; then
  nmcli connection delete id "$ssid" >/dev/null 2>&1
  msg "Wrong password or failed: $ssid"
fi
