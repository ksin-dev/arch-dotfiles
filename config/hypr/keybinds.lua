local mainMod = "SUPER"
local terminal = "alacritty"
local fileManager = "yazi"
local guiFileManager = "nautilus"
local menu = "~/.local/bin/qs-toggle-launcher"

local function exec(keys, command, description, options, rules)
    options = options or {}
    options.description = description
    hl.bind(keys, hl.dsp.exec_cmd(command, rules), options)
end

local function bind(keys, dispatcher, description, options)
    options = options or {}
    options.description = description
    hl.bind(keys, dispatcher, options)
end

-- @group Apps
exec(mainMod .. " + Return", terminal, "Open terminal") -- help: Open terminal
exec(mainMod .. " + CTRL + escape", terminal .. " --title dotfiles-btop -e btop", "Open btop", nil, {
    float = true,
    size = { "80%", "80%" },
    center = true,
}) -- help: Open btop
exec(mainMod .. " + E", "kitty -e " .. fileManager, "Open terminal file manager", nil, {
    float = true,
    size = { "80%", "70%" },
    center = true,
}) -- help: Open terminal file manager
exec(mainMod .. " + SHIFT + E", guiFileManager, "Open GUI file manager") -- help: Open GUI file manager
exec(mainMod .. " + Space", menu, "Open app launcher") -- help: Open app launcher
exec(mainMod .. " + SHIFT + slash", "~/.local/bin/qs-toggle-keybinds", "Show keyboard shortcuts") -- help: Show keyboard shortcuts
exec(mainMod .. " + SHIFT + question", "~/.local/bin/qs-toggle-keybinds", "Show keyboard shortcuts") -- help: Show keyboard shortcuts
exec(mainMod .. " + P", "~/.local/bin/hypr-monitor-cycle", "Cycle display mode") -- help: Cycle display mode
exec(mainMod .. " + SHIFT + P", "~/.local/bin/qs-monitor-settings", "Open display settings") -- help: Open display settings

-- @group Windows
bind(mainMod .. " + Q", hl.dsp.window.close(), "Close active window") -- help: Close active window
exec(mainMod .. " + SHIFT + Q", [[sh -c 'pid=$(hyprctl activewindow -j | jq -r ".pid"); [ -n "$pid" ] && [ "$pid" != "null" ] && kill -KILL "$pid"']], "Force-kill active window") -- help: Force-kill active window
bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), "Toggle floating") -- help: Toggle floating
bind(mainMod .. " + ALT + P", hl.dsp.window.pseudo(), "Toggle pseudo tiling") -- help: Toggle pseudo tiling

local directions = {
    left = "left", right = "right", up = "up", down = "down",
    h = "left", l = "right", k = "up", j = "down",
}
for key, direction in pairs(directions) do
    bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = direction }), "Move focus " .. direction)
end

bind(mainMod .. " + Tab", hl.dsp.window.cycle_next(), "Cycle next window") -- help: Cycle next window
bind(mainMod .. " + F", hl.dsp.window.fullscreen(), "Toggle fullscreen") -- help: Toggle fullscreen

-- @group Window layouts
bind(mainMod .. " + ALT + W", hl.dsp.submap("window_layout"), "Toggle window layout mode") -- help: Toggle window layout mode
hl.define_submap("window_layout", function()
    bind(mainMod .. " + ALT + W", hl.dsp.submap("reset"), "Exit window layout mode") -- help: Exit window layout mode
    exec("1", "~/.config/hypr/master-layout.sh top", "Layout 1: main top") -- help: Layout 1: main top
    exec("2", "~/.config/hypr/master-layout.sh left", "Layout 2: main left") -- help: Layout 2: main left
    exec("3", "~/.config/hypr/master-layout.sh right", "Layout 3: main right") -- help: Layout 3: main right
    exec("4", "~/.config/hypr/dwindle-layout.sh", "Layout 4: dwindle") -- help: Layout 4: dwindle
    exec("5", "~/.config/hypr/master-layout.sh top all", "Layout 5: equal horizontal split") -- help: Layout 5: equal horizontal split
    for key, direction in pairs(directions) do
        bind(key, hl.dsp.focus({ direction = direction }), "Move focus " .. direction)
    end
    exec("m", "~/.config/hypr/set-master-window.sh", "Set focused window as master") -- help: Set focused window as master
    bind("escape", hl.dsp.submap("reset"), "Exit window layout mode") -- help: Exit window layout mode
end)

-- @group Music
bind(mainMod .. " + ALT + M", hl.dsp.submap("music"), "Toggle music mode") -- help: Toggle music mode
hl.define_submap("music", function()
    bind(mainMod .. " + ALT + M", hl.dsp.submap("reset"), "Exit music mode") -- help: Exit music mode
    exec("k", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", "Increase volume", { repeating = true, locked = true }) -- help: Increase volume
    exec("up", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", "Increase volume", { repeating = true, locked = true }) -- help: Increase volume
    exec("j", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", "Decrease volume", { repeating = true, locked = true }) -- help: Decrease volume
    exec("down", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", "Decrease volume", { repeating = true, locked = true }) -- help: Decrease volume
    exec("l", "playerctl next", "Next media track", { locked = true }) -- help: Next media track
    exec("right", "playerctl next", "Next media track", { locked = true }) -- help: Next media track
    exec("h", "playerctl previous", "Previous media track", { locked = true }) -- help: Previous media track
    exec("left", "playerctl previous", "Previous media track", { locked = true }) -- help: Previous media track
    exec("space", "playerctl play-pause", "Toggle media playback", { locked = true }) -- help: Toggle media playback
    exec("s", "playerctl shuffle Toggle", "Toggle shuffle", { locked = true }) -- help: Toggle shuffle
    exec("r", [[sh -c 'state=$(playerctl loop 2>/dev/null || true); if [ "$state" = Playlist ]; then playerctl loop None; else playerctl loop Playlist; fi']], "Toggle repeat playlist", { locked = true }) -- help: Toggle repeat playlist
    bind("escape", hl.dsp.submap("reset"), "Exit music mode") -- help: Exit music mode
end)

-- @group Resize
bind(mainMod .. " + ALT + R", hl.dsp.submap("resize"), "Toggle resize mode") -- help: Toggle resize mode
hl.define_submap("resize", function()
    bind(mainMod .. " + ALT + R", hl.dsp.submap("reset"), "Exit resize mode") -- help: Exit resize mode
    local resize = {
        right = { 10, 0 }, left = { -10, 0 }, up = { 0, -10 }, down = { 0, 10 },
        l = { 10, 0 }, h = { -10, 0 }, k = { 0, -10 }, j = { 0, 10 },
    }
    for key, delta in pairs(resize) do
        bind(key, hl.dsp.window.resize({ x = delta[1], y = delta[2], relative = true }), "Resize active window", { repeating = true })
    end
    bind("escape", hl.dsp.submap("reset"), "Exit resize mode") -- help: Exit resize mode
end)

-- @group Workspaces
for workspace = 1, 10 do
    local key = tostring(workspace % 10)
    bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = workspace }), "Switch to workspace " .. workspace) -- help: Switch workspace
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }), "Move window to workspace " .. workspace) -- help: Move window to workspace
end
bind(mainMod .. " + Z", hl.dsp.workspace.toggle_special("magic"), "Toggle scratchpad workspace") -- help: Toggle scratchpad workspace
bind(mainMod .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "special:magic" }), "Move window to scratchpad") -- help: Move window to scratchpad
bind(mainMod .. " + M", hl.dsp.workspace.toggle_special("music"), "Toggle music workspace") -- help: Toggle music workspace
bind(mainMod .. " + SHIFT + M", hl.dsp.window.move({ workspace = "special:music" }), "Move window to music workspace") -- help: Move window to music workspace
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Switch to next workspace") -- help: Switch to next workspace
bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "Switch to previous workspace") -- help: Switch to previous workspace

-- @group Screenshots
exec(mainMod .. " + S", [[sh -c 'grim -g "$(hyprctl activewindow -j | jq -r "\"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])\"")" - | swappy -f -']], "Screenshot active window") -- help: Screenshot active window
exec(mainMod .. " + SHIFT + S", [[sh -c 'grim -g "$(slurp -d)" - | swappy -f -']], "Screenshot selected region") -- help: Screenshot selected region

-- @group System
exec(mainMod .. " + SHIFT + L", [[sh -c 'if command -v hyprlock >/dev/null 2>&1; then pidof hyprlock >/dev/null 2>&1 || hyprlock; else loginctl lock-session; fi']], "Lock screen") -- help: Lock screen
exec(mainMod .. " + CTRL + Q", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'", "Logout or shutdown") -- help: Logout or shutdown
exec("ALT_R", "fcitx5-remote -t", "Toggle Korean input") -- help: Toggle Korean input
exec("Hangul", "fcitx5-remote -t", "Toggle Korean input") -- help: Toggle Korean input
exec("ISO_Level3_Shift", "fcitx5-remote -t", "Toggle Korean input") -- help: Toggle Korean input

-- @group Mouse
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), "Move window by dragging", { mouse = true }) -- help: Move window by dragging
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), "Resize window by dragging", { mouse = true }) -- help: Resize window by dragging

-- @group Media
exec("XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", "Increase volume", { repeating = true, locked = true }) -- help: Increase volume
exec("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", "Decrease volume", { repeating = true, locked = true }) -- help: Decrease volume
exec("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "Toggle audio mute", { repeating = true, locked = true }) -- help: Toggle audio mute
exec("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", "Toggle microphone mute", { repeating = true, locked = true }) -- help: Toggle microphone mute
exec("XF86MonBrightnessUp", "brightnessctl -e4 -n2 set 5%+", "Increase brightness", { repeating = true, locked = true }) -- help: Increase brightness
exec("XF86MonBrightnessDown", "brightnessctl -e4 -n2 set 5%-", "Decrease brightness", { repeating = true, locked = true }) -- help: Decrease brightness
exec("XF86AudioNext", "playerctl next", "Next media track", { locked = true }) -- help: Next media track
exec("XF86AudioPause", "playerctl play-pause", "Toggle media playback", { locked = true }) -- help: Toggle media playback
exec("XF86AudioPlay", "playerctl play-pause", "Toggle media playback", { locked = true }) -- help: Toggle media playback
exec("XF86AudioPrev", "playerctl previous", "Previous media track", { locked = true }) -- help: Previous media track
