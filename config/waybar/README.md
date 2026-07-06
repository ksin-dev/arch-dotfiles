# Waybar

Legacy status bar configuration for Hyprland.

The active desktop shell now uses Quickshell from `config/quickshell/shell.qml`.
This Waybar config is kept as a reference and fallback, especially for comparing
modules while preserving status-bar behavior.

## Files

- `config.jsonc`: module layout and module behavior
- `style.css`: colors, spacing, fonts, and visual style

## Required

- `waybar`
- A Nerd Font if icons are used in labels or custom modules

## Common Optional Dependencies

Depending on enabled modules:

- `wireplumber` or `pipewire`: audio status
- `networkmanager`: network status
- `bluez`: Bluetooth status
- `upower`: battery status on some systems
- `playerctl`: media status
- `hyprland`: Hyprland workspaces/window modules
- `wlogout`: power button menu

## Install

From the repository root:

```sh
./install.sh waybar
```

Do not enable Waybar and the Quickshell top bar at the same time unless you
explicitly want two bars.

Restart Waybar after changes:

```sh
pkill waybar
waybar &
```

Hyprland can also start this config explicitly:

```ini
exec-once = waybar --config ~/.config/waybar/config.jsonc --style ~/.config/waybar/style.css
```

The current Hyprland autostart uses Quickshell instead.
