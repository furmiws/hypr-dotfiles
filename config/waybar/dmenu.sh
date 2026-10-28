#!/usr/bin/env bash
# translates wofi-style arguments into fuzzel
prompt="> "; xoff=0; width=320; height=300; pw=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prompt)   prompt="$2 "; shift ;;
    --xoffset)  xoff="$2"; shift ;;
    --width)    width="$2"; shift ;;
    --height)   height="$2"; shift ;;
    --location) shift ;;
    --password) pw=1 ;;
  esac
  shift
done
xm=$(( xoff < 0 ? -xoff : 0 ))
chars=$(( width / 10 ))
lines=$(( height / 32 )); [ "$lines" -lt 1 ] && lines=1
common=(--anchor=bottom-right --x-margin="$xm" --y-margin=36 --width="$chars" --lines="$lines" --font="JetBrainsMono Nerd Font:size=9" --background=000000ff --text-color=ffffffff --match-color=ffffffff --selection-color=ffffffff --selection-text-color=000000ff --selection-match-color=000000ff --border-color=ffffffff --border-width=2 --border-radius=8 --horizontal-pad=10 --vertical-pad=8 --inner-pad=4)
if [ "$pw" = 1 ]; then
  exec fuzzel --prompt-only="$prompt" --password "${common[@]}"
else
  exec fuzzel --dmenu --hide-prompt --mesg="${prompt% }" "${common[@]}"
fi
