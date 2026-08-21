local variables = {
    GTK_IM_MODULE = "fcitx",
    QT_IM_MODULE = "fcitx",
    XMODIFIERS = "@im=fcitx",
    SDL_IM_MODULE = "fcitx",
    GLFW_IM_MODULE = "fcitx",
    XCURSOR_SIZE = "24",
    HYPRCURSOR_SIZE = "23",
    MOZ_ENABLE_WAYLAND = "1",
    SDL_VIDEODRIVER = "wayland",
}

for name, value in pairs(variables) do
    hl.env(name, value)
end
