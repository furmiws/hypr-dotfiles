#!/bin/bash
pgrep -x wofi >/dev/null && { pkill -x wofi; exit; }

XOFF=-470
menu() { wofi --dmenu --hide-search --location 5 --xoffset "$XOFF" --width 320 --height 340 --prompt "$1"; }
msg() { printf '%s\n' "$1" | wofi --dmenu --hide-search --location 5 --xoffset "$XOFF" --width 320 --height 90 --prompt Bluetooth >/dev/null; }

# Bluetooth is off: only offer to turn it on
if ! bluetoothctl show | grep -q "Powered: yes"; then
  choice=$(printf 'Turn Bluetooth on\n' | menu Bluetooth)
  [ -n "$choice" ] && { rfkill unblock bluetooth; bluetoothctl power on >/dev/null; }
  exit
fi

declare -A map state
lines=""
while read -r _ mac name; do
  [ -z "$name" ] && continue
  [ "${name//-/:}" = "$mac" ] && continue
  info=$(bluetoothctl info "$mac")
  if grep -q "Connected: yes" <<<"$info"; then mark="● "; st=connected
  elif grep -q "Paired: yes" <<<"$info"; then mark="○ "; st=paired
  else mark="  "; st=new; fi
  line="${mark}${name}"
  map[$line]=$mac
  state[$mac]=$st
  lines+="$line"$'\n'
done < <(bluetoothctl devices)

choice=$( { printf 'Turn Bluetooth off\nScan for devices\nOpen Bluetooth manager\n'; printf '%s' "$lines"; } | menu Bluetooth )
[ -z "$choice" ] && exit

case "$choice" in
  "Turn Bluetooth off") bluetoothctl power off >/dev/null; exit ;;
  "Open Bluetooth manager") blueman-manager & exit ;;
  "Scan for devices")
    ( bluetoothctl --timeout 6 scan on >/dev/null 2>&1 & )
    printf 'Scanning for devices...\n' | timeout 6 wofi --dmenu --hide-search --location 5 --xoffset "$XOFF" --width 320 --height 90 >/dev/null
    exec "$0" ;;
esac

mac=${map[$choice]}
[ -z "$mac" ] && exit
name=${choice:2}

case "${state[$mac]}" in
  connected)
    bluetoothctl disconnect "$mac" >/dev/null 2>&1 ;;
  paired)
    timeout 20 bluetoothctl connect "$mac" 2>&1 | grep -q successful || msg "Could not connect to $name" ;;
  new)
    timeout 30 bluetoothctl pair "$mac" 2>&1 | grep -q successful || { msg "Pairing failed: $name"; exit; }
    bluetoothctl trust "$mac" >/dev/null 2>&1
    timeout 20 bluetoothctl connect "$mac" 2>&1 | grep -q successful || msg "Paired, but could not connect to $name" ;;
esac
