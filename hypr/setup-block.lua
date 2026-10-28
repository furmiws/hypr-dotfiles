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
-- <<< dotfiles-setup <<<
