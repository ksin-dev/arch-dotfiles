# Hyprland

Hyprland desktop configuration.

## Files

- `hyprland.lua`: main Hyprland config, appearance, rules, and autostart
- `environment.lua`: Wayland and input method environment variables
- `keybinds.lua`: generated and hand-written keyboard/mouse bindings
- `monitors.lua`: Lua loader for the machine-local nwg-displays output
- `monitors.conf`: generic monitor fallback; the real machine-local layout is
  stored outside the repo at `~/.config/dotfiles/hypr/monitors.conf`
- `../dotfiles/hypr/workspaces.conf.example`: optional local workspace rule
  template; real monitor-specific workspace rules live outside the repo at
  `~/.config/dotfiles/hypr/workspaces.conf`
- `theme/palette.lua`: generated palette data consumed by `hyprland.lua`
- `hypridle.conf` and `hyprlock.conf`: these tools still use Hyprlang

The old Hyprland `.conf` files remain as a temporary rollback copy. Hyprland
prefers `hyprland.lua` automatically, so they are not loaded during a normal
session and can be removed after the Lua setup has been used successfully.

## Required

- `hyprland`
- `quickshell`
- `hyprpaper`
- `hypridle`
- `hyprlock`
- `bluez`: Bluetooth daemon and `bluetoothctl`
- `blueman`: Bluetooth manager and Hyprland tray applet
- `fcitx5`
- `kitty`
- `yazi`
- `nautilus`
- `jq`
- `nwg-displays`

## Optional Features

- `hyprpm`: used by `hyprpm reload -n`
- `hyprshutdown`: preferred shutdown menu when installed
- `btop`: opened by `SUPER+CTRL+Esc`
- `alacritty`: kept in this dotfiles repo as an optional legacy terminal config
- `grim`, `slurp`, `swappy`: screenshot workflow
- `wf-recorder`: optional Quick Utilities screen recording toggle; `slurp` is
  used for region selection when installed
- `brightnessctl`: brightness keys
- `wireplumber` or `pipewire`: `wpctl` volume commands
- `playerctl`: media keys
- `loginctl` and `systemctl`: Quickshell power dropdown actions
- `networkmanager`: Quickshell network status through `nmcli`
- `power-profiles-daemon`: Quickshell power profile status and switching
- `cliphist` and `wl-clipboard`: clipboard history in Quick Utilities;
  the `hyprland.start` callback starts the `wl-paste --watch
  cliphist store` watcher

## Install Packages

`./install.sh hypr` installs the required Arch packages automatically when
`pacman` is available. Packages that are not in the enabled repositories are
installed through `paru` or `yay` when either helper is present.

To only copy files and skip package installation:

```sh
DOTFILES_SKIP_PACKAGES=1 ./install.sh hypr
```

Manual install on Arch Linux:

```sh
sudo pacman -S hyprland hyprpaper hypridle hyprlock bluez blueman fcitx5 fcitx5-hangul kitty yazi nautilus jq nwg-displays grim slurp swappy
```

Quickshell is installed from AUR if it is not already available:

```sh
paru -S quickshell-git
```

The installer also creates `~/.config/swappy/config` when it does not already
exist. Screenshots saved from Swappy are written to
`~/Pictures/Screenshots` by default.

## Bluetooth

When `hypr` is installed, the installer enables and starts BlueZ through
`bluetooth.service`. Hyprland starts `blueman-applet` for its tray icon; the
same manager is available from the Quickshell Bluetooth panel. To start the
service manually:

```sh
sudo systemctl enable --now bluetooth.service
```

## Launcher

The application launcher is implemented in Quickshell and is toggled with
`SUPER+Space` or `CTRL+Space`.

## File Managers

- `SUPER+E`: open `yazi` in Kitty for terminal-first file management
- `SUPER+SHIFT+E`: open `nautilus` as the GUI file manager

Relevant files:

- `hyprland.lua`
- `keybinds.lua`
- `../quickshell/shell.qml`
- `../../bin/qs-toggle-launcher`

## Displays

- `SUPER+P`: cycle the current monitor mode through extend, duplicate,
  primary-only, and secondary-only. This is meant for quick projector-style
  switching and applies the layout through `hyprctl`.
- `SUPER+SHIFT+P`: open `nwg-displays` for detailed monitor setup, including
  resolution, refresh rate, scale, position, and primary display.
- `SUPER+ALT+P`: toggle Hyprland pseudo tiling. This was moved away from
  `SUPER+P` so display mode switching can use the conventional shortcut.

`nwg-displays` saves Hyprland monitor rules to
`~/.config/dotfiles/hypr/monitors.conf`. `monitors.lua` reads the monitor rules
from that file and converts them to `hl.monitor()` calls. Optional workspace
rules in `~/.config/dotfiles/hypr/workspaces.conf` are converted to
`hl.workspace_rule()` calls. This compatibility loader keeps nwg-displays
usable while the active Hyprland configuration remains Lua.

## Keyboard Shortcuts

The keybind help overlay is implemented in Quickshell and toggled with `SUPER+?`
(`SUPER+SHIFT+/`).

The overlay is generated from comments in `keybinds.lua`:

```lua
-- @group Apps
exec(mainMod .. " + Return", terminal, "Open terminal") -- help: Open terminal
```

Relevant files:

- `keybinds.lua`
- `../quickshell/components/KeybindHelp.qml`
- `../../bin/qs-toggle-keybinds`

Quickshell launcher behavior:

- search input keeps keyboard focus
- matching apps are filtered by name, description, and desktop app id
- the desktop app id is shown on the right
- `Up`/`Down` and `K`/`J` move the selected result
- `Enter` launches the selected result
- `Esc` closes the launcher

## Quickshell Top Bar

The active top bar is implemented in `../quickshell/shell.qml`.

Current widgets:

- active workspace
- active window title
- MPRIS media dropdown through Quickshell `Mpris`
- clock
- power profile through Quickshell `UPower` power profiles
- CPU load
- memory usage
- temperature from `/sys/class/thermal`
- backlight from `/sys/class/backlight` when available
- laptop battery percentage and meter when a system battery is available
- status icons for audio, microphone, keyboard layout, network, Bluetooth, and
  brightness, each opening a themed detail dropdown
- StatusNotifier/AppIndicator tray items through Quickshell `SystemTray`
- compact Quickshell power dropdown with power profile controls
- PipeWire/WirePlumber volume and mute controls through `wpctl`
- Korean calendar with month/year picker and fixed-date Korean holidays
- dark/light color scheme picker backed by `apply-theme.sh`
- searchable Hyprland/Yazi keybind help overlay
- visible Hyprland submap indicator for resize/music modes
- optional Quickshell notification/snackbar server

The `System` dropdown is reserved for computer resource state only: power
profile, CPU load, memory, temperature, backlight, and battery. Audio, network,
Bluetooth, and keyboard controls live in separate status dropdowns. Their
settings actions are shown dynamically only when a supported provider command is
installed.

System-level tools use symbolic icons. External application tray items use the
application-provided icon and appear dynamically only while the application
registers a StatusNotifier/AppIndicator item.

Laptop battery also appears directly on the top bar with a percentage and small
meter. It is hidden on desktops or when only peripheral batteries are present.

Fcitx5 is shown through its own tray item when it registers one, so the bar does
not render a separate input-method badge.

## Notifications

The right-side notification toast/snackbar is provided by Quickshell. Legacy
notification daemons such as `mako` and `dunst` should stay uninstalled or
masked because only one process can own the desktop notification service.

Use:

```sh
qs-notifications status
qs-notifications enable
qs-notifications disable
```

`qs-notifications enable` masks legacy daemons, enables the Quickshell
`NotificationServer`, and restarts Quickshell. `disable` only turns the
Quickshell server off; it does not start another notification daemon.

## Theme

The repository-level theme script generates palette data for Hyprland:

```sh
./apply-theme.sh default
./apply-theme.sh graphite
./apply-theme.sh --list
```

Generated file:

```text
config/hypr/theme/palette.lua
```

`hyprland.lua` loads this data and computes the Hyprland color values itself.
The theme script finishes with `hyprctl reload`, so changes apply immediately.

## Screen Lock

Screen locking and idle power actions are handled by `hypridle`. The generated
runtime config lives at `~/.config/dotfiles/hypr/hypridle.generated.conf` and
is managed by `hypr-idle-settings`.

- `SUPER+SHIFT+L`: lock immediately, preferring `hyprlock`
- default 5 minutes idle: lock with `hyprlock`, falling back to `loginctl`
- default 10 minutes idle: turn displays off
- default 15 minutes idle: suspend system
- Quickshell Power -> Idle settings: adjust lock, display-off, suspend, and
  hibernate timers

Relevant files:

- `hypridle.conf`
- `../../bin/hypr-idle-settings`
- `../dotfiles/hypr/idle.json.example`
- `hyprlock.conf`
- `hyprland.lua`
- `keybinds.lua`

## Install

From the repository root:

```sh
./install.sh hypr
```

Or run `./install.sh` and select `hypr` from the menu.

## Notes

The `hyprland.start` callback in `hyprland.lua` starts:

```text
fcitx5, Quickshell, hyprpaper, hypr-idle-settings, clipboard watcher, hyprpm reload
```

The active top bar is implemented with Quickshell in
`../quickshell/shell.qml`.
