# Hyprland black & white setup

> This is my **new and best** Hyprland config! I made a [first one](https://github.com/furmiws/Hyprconfs) and... it wasn't great, lol. This one is a full rewrite: black and white, a Waybar with popups, and a one-command installer.


A minimal black and white Hyprland desktop: Waybar with popups, Fuzzel, Mako, Wofi menus and a custom Fastfetch.

## What's included

- **Waybar** (bottom bar): workspaces 1-3, music title and controls, clock popup with calendar, volume, Bluetooth, Wi-Fi, CPU, RAM, storage and battery popups, and a power menu
- **Fuzzel** app launcher (SUPER + D)
- **Mako** notifications
- **Wofi** styling for the popups
- **Fastfetch** with a custom logo

## Requirements

- Arch Linux (or an Arch-based distro) with pacman
- Hyprland 0.55+ using the Lua config (`~/.config/hypr/hyprland.lua`)
- Working audio (PipeWire)

## Install

    git clone https://github.com/furmiws/hypr-dotfiles.git
    cd hypr-dotfiles
    ./install.sh

Existing configs are backed up as `*.bak-<date>` before anything is replaced.

## Notes

- The installer offers `waybar-git` from the AUR because the packaged Waybar can't click workspaces on Hyprland 0.55 Lua configs.
- On machines without a battery, the battery module is removed automatically.
- The Wi-Fi, Bluetooth, RAM and storage popups are positioned by guesswork. If one is off, change the `XOFF` value at the top of its script in `~/.config/waybar/`.
- Replace `config/fastfetch/logo.png` with your own image if you like.
