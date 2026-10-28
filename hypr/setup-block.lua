-- >>> dotfiles-setup >>>
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
end)

hl.window_rule({
    name  = "clock-popup",
    match = { class = "^(clock-popup)$" },
    float = true,
    size  = "260 230",
    move  = "830 810",
})

hl.window_rule({
    name  = "btop-popup",
    match = { class = "^(btop-popup)$" },
    float = true,
    size  = "900 560",
    center = true,
})

hl.bind("SUPER + D", hl.dsp.exec_cmd("fuzzel"))
hl.on("hyprland.start", function()
    hl.exec_cmd("swaybg -i $HOME/.config/wallpaper/wallpaper.png -m fill")
end)

-- black window borders
hl.config({
    general = {
        border_size = 2,
        col = {
            active_border = "rgba(000000ff)",
            inactive_border = "rgba(000000ff)",
        },
    },
})

-- lock screen: idle daemon and key
hl.on("hyprland.start", function()
    hl.exec_cmd("hypridle")
end)

hl.bind("SUPER + L", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))

-- <<< dotfiles-setup <<<
