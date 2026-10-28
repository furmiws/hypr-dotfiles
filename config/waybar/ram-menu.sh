#!/usr/bin/env bash
pgrep -x fuzzel >/dev/null && { pkill -x fuzzel; exit; }
XOFF=-205

total=$(free -h | awk '/^Mem:/{print $3" / "$2}')
list=$(ps -eo rss=,comm= \
  | awk '{r=$1; $1=""; sub(/^ /,""); m[$0]+=r} END{for(k in m) printf "%d\t%s\n", m[k], k}' \
  | sort -rn | head -n 10 \
  | awk -F'\t' '{ if ($1>=1048576) s=sprintf("%.1f GB",$1/1048576); else s=sprintf("%d MB",$1/1024); printf "%-9s %s\n", s, $2 }')

{ printf 'Memory  %s\n' "$total"; printf '────────────────────\n'; printf '%s\n' "$list"; } \
  | $HOME/.config/waybar/dmenu.sh --dmenu --hide-search --location 5 --xoffset "$XOFF" --width 320 --height 340 --prompt RAM >/dev/null
