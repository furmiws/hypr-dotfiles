#!/usr/bin/env bash
if pgrep -f "class clock-popup" > /dev/null; then
    pkill -f "class clock-popup"
else
    kitty --class clock-popup -o background=#000000 -o foreground=#ffffff -e bash -c '
        tput civis
        sleep 0.3
        clear
        while true; do
            tput cup 0 0
            printf "\033[K\n   %s\033[K\n\033[K\n" "$(date +%H:%M:%S)"
            cal -m | sed "s/\$/\x1b[K/"
            tput ed
            if read -rsn1 -t 1 key; then
                [[ $key == $'"'"'\e'"'"' || $key == q ]] && exit
            fi
        done
    ' &
fi
