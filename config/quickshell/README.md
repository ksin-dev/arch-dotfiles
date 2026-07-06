# Quickshell

Quickshell is the QtQuick/QML desktop shell used for the Hyprland bar and
launcher.

## Required Packages

```sh
paru -S quickshell-git
```

The current config targets Quickshell `0.3.x`.

## Files

- `shell.qml`: main shell entrypoint
- `components/BackgroundLayer.qml`: optional desktop clock and animated background visualiser
- `components/DesktopBar.qml`: Hyprland top bar, status widgets, dropdowns, and tray
- `components/KeybindHelp.qml`: searchable Hyprland/Yazi shortcut overlay
- `components/Notifications.qml`: optional Quickshell notification/snackbar UI
- `components/SubmapIndicator.qml`: visible mode indicator for Hyprland submaps
- `components/PollText.qml`: small command polling helper for resource status
- `services/KeybindParser.js`: parser for Hyprland help comments and Yazi keymaps
- `services/ShellCommands.js`: shared shell formatting helpers
- `Theme.js`: generated shared color tokens
- `../../bin/qs-toggle-launcher`: Hyprland keybind entrypoint for the launcher
- `../../bin/qs-toggle-keybinds`: Hyprland keybind entrypoint for shortcut help
- `../../bin/qs-notifications`: enable or disable Quickshell notifications
- `../../bin/qs-shell`: small `qs ipc call` wrapper with Caelestia-style target
  listing

## Run

```sh
qs -p ~/.config/quickshell
```

or from this repository:

```sh
qs -p config/quickshell
```

## Current Scope

Current Quickshell scope:

- Caelestia-style floating top panel modules on every monitor
- OS logo launcher button backed by `/etc/os-release`, with a text fallback
- compact dashboard appbar button with profile, uptime, quick resource metrics,
  now playing, performance, and weather summaries
- Hyprland workspace pill that shows the focused workspace by default,
  expands to 10 workspace buttons on hover, marks occupied workspaces, and
  shows small per-workspace app icons with an overflow count when windows are
  present; it also supports wheel switching; when a special workspace is open,
  wheel input closes that scratchpad before switching normal workspaces
- active Hyprland special workspace indicator next to the workspace pill
- active window app icon and title with a compact detail/control dropdown
- fullscreen-aware compact mode that hides distraction-heavy modules while
  keeping clock, core status, and power controls visible
- clock
- shared theme colors
- application and action launcher on `SUPER+Space` and `CTRL+Space`
- MPRIS media summary and dropdown
- MPRIS player switcher in the media dropdown when multiple players are active
- MPRIS player aliases and priority selection for common players such as
  Spotify, YouTube/Chrome, Firefox, VLC, mpv, Elisa, and KDE Connect
- PipeWire/WirePlumber default sink volume and mute controls through `wpctl`
- microphone mute control through `pactl` in the audio dropdown
- system resource dropdown for profile, CPU load, memory, storage, network
  traffic, temperature, GPU when detectable, backlight, and battery
- CPU and memory compact summary on the top bar
- performance-style resource meters in the system dropdown
- laptop battery meter on the top bar when present
- laptop battery state and remaining/charging time in the power dropdown when
  `upower` exposes a battery device
- configurable low-battery notifications through `general.battery.warnLevels`
  with optional critical actions
- desktop power profile pill on the top bar when no laptop battery is present
- status icon group for audio, microphone, keyboard layout, network,
  Bluetooth, brightness, battery, and lock-key states
- compact audio, network, and brightness pills show current values directly on
  the top bar
- top-bar audio and brightness pills support mouse-wheel adjustment with OSD
  feedback
- Bluetooth status hides itself when no adapter/service is available and
  distinguishes off, ready, and connected states
- privacy indicator appears only when microphone capture, camera use, or common
  screen recording processes are detected
- package update indicator appears when `checkupdates`, `paru`, or `yay`
  report pending updates
- optional weather pill appears when `services.weatherLocation` or
  `~/.config/dotfiles/weather-location` is configured and `curl` can reach
  `wttr.in`
- high temperature indicator appears on the top bar when thermal sensors report
  70°C or higher
- active idle-inhibit state appears as a warning status chip on the bar
- Caps Lock and Num Lock indicators appear as separate warning chips when
  enabled
- audio, network, Bluetooth, keyboard, and brightness detail dropdowns when
  matching session commands exist
- Wi-Fi signal-aware network status icon when NetworkManager reports signal
  strength
- saved Wi-Fi NetworkManager connection shortcuts through `nmcli`
- compact Nexus network overview with current connection, traffic, nearby
  Wi-Fi networks, saved connections, and NetworkManager tools
- paired Bluetooth device connect shortcuts through `bluetoothctl`
- StatusNotifier/AppIndicator tray through Quickshell `SystemTray`
- themed tray menu rendering for first-level menus and nested submenu
  navigation, with native menu fallback for tray apps that expose incomplete
  DBus menu children
- compact power dropdown with lock/suspend/logout/reboot/shutdown, idle timer
  settings, and power profile switching when `power-profiles-daemon` is
  available
- Korean calendar dropdown with fixed-date Korean holidays
- calendar dropdown summarizes the next weekend and next fixed Korean holiday
- top-bar `Appearance` picker with separate `Mode` and `Color scheme` display,
  dark/light mode sections, and `apply-theme.sh` integration; generated
  `Theme.js` exposes both `mode` and `colorScheme`
- quick utilities dropdown for notification DND, NordVPN when installed,
  screenshot capture, and system settings
- themed volume and brightness OSD feedback for scroll/slider changes
- searchable shortcut overlay on `SUPER+?`
- Hyprland submap indicator for resize/music modes
- optional Quickshell notification/snackbar server
- notification history count badge on the top-bar notification button
- notification center exposed as a Caelestia-style right sidebar with optional
  edge-hover reveal
- optional background layer with desktop clock and a theme-coloured animated
  visualiser

The bar borrows the overall appbar direction from Caelestia Shell: separate
rounded modules, compact status icons, tray popouts, and per-feature dropdowns.
It is not a one-to-one clone. Larger Caelestia surfaces such as lock, nexus, and
full network management are represented as compact local equivalents rather than
full replacements.

## User Configuration

Optional user configuration is read from:

```text
~/.config/dotfiles/quickshell.json
```

If the file is missing or a key is omitted, the current default behavior is used.
This keeps personal UI preferences outside the installed Quickshell source and
prevents `install.sh` from overwriting them.

Start from:

```text
config/dotfiles/quickshell.json.example
```

Supported appbar entry toggles:

```json
{
  "general": {
    "logo": "",
    "showOverFullscreen": false,
    "apps": {
      "terminal": ["kitty", "alacritty"],
      "audio": ["pavucontrol", "pwvucontrol"],
      "network": ["nm-connection-editor"],
      "explorer": ["nautilus", "thunar", "dolphin"],
      "settings": ["gnome-control-center", "systemsettings"],
      "playback": ["spotify", "youtube-music", "mpv", "vlc", "elisa"]
    }
  },
  "appearance": {
    "deformScale": 1,
    "anim": {
      "enabled": true,
      "durationScale": 1
    },
    "transparency": {
      "enabled": false,
      "barOpacity": 0.96,
      "panelOpacity": 1,
      "osdOpacity": 0.98
    },
    "rounding": 1,
    "spacing": {
      "scale": 1
    },
    "padding": {
      "scale": 1
    },
    "font": {
      "scale": 1,
      "clock": "",
      "workspaces": "",
      "label": {
        "family": "",
        "medium": { "size": 10 },
        "small": { "size": 8 }
      },
      "body": {
        "family": "",
        "medium": { "size": 10 },
        "small": { "size": 8 }
      },
      "title": {
        "family": "",
        "medium": { "size": 11 },
        "small": { "size": 9 }
      }
    }
  },
  "calendar": {
    "font": {
      "scale": 1,
      "labelSize": 8,
      "titleSize": 9,
      "detailSize": 7,
      "daySize": 9
    }
  },
  "panel": {
    "font": {
      "scale": 1,
      "titleSize": 9,
      "labelSize": 7,
      "bodySize": 7,
      "metaSize": 6,
      "heroSize": 11,
      "iconSize": 17
    }
  },
  "bar": {
    "enabled": true,
    "persistent": true,
    "showOnHover": false,
    "dragThreshold": 20,
    "excludedScreens": [],
    "font": {
      "scale": 1,
      "labelSize": 8,
      "bodySize": 8,
      "clockSize": 9,
      "badgeSize": 6,
      "workspaceIconSize": 6
    },
    "scrollActions": {
      "workspaces": true,
      "volume": true,
      "brightness": true
    },
    "popouts": {
      "activeWindow": true,
      "tray": true,
      "statusIcons": true
    },
    "logo": { "enabled": true },
    "workspaces": {
      "enabled": true,
      "shown": 10,
      "label": "",
      "occupiedLabel": "",
      "activeLabel": "",
      "maxWindowIcons": 9,
      "activeIndicator": true,
      "activeTrail": true,
      "perMonitorWorkspaces": true,
      "occupiedBg": true,
      "showWindows": true,
      "showWindowsOnSpecialWorkspaces": true,
      "capitalisation": "preserve",
      "specialWorkspaceIcons": [
        { "name": "steam", "icon": "applications-games-symbolic" },
        { "name": "music", "icon": "multimedia-player-symbolic" }
      ],
      "windowIcons": [
        { "regex": "youtube|chrome-.*youtube", "icon": "youtube-music" },
        { "regex": "spotify", "icon": "spotify" },
        { "regex": "discord", "icon": "discord" }
      ]
    },
    "activeWindow": {
      "enabled": true,
      "compact": false,
      "inverted": false,
      "showOnHover": true
    },
    "dashboard": { "enabled": true },
    "media": { "enabled": true },
    "clock": {
      "enabled": true,
      "background": true,
      "showDate": true,
      "showIcon": false
    },
    "system": { "enabled": true },
    "power": { "enabled": true },
    "statusIcons": { "enabled": true },
    "tray": {
      "enabled": true,
      "background": true,
      "compact": false,
      "recolour": false,
      "iconSize": 16,
      "preferNativeMenu": false,
      "nativeMenuFallback": true,
      "hiddenIcons": [],
      "iconSubs": []
    },
    "appearance": { "enabled": true },
    "quickUtilities": { "enabled": true },
    "nexus": { "enabled": true },
    "notifications": { "enabled": true },
    "entries": [
      { "id": "logo", "enabled": true },
      { "id": "dashboard", "enabled": true },
      { "id": "workspaces", "enabled": true },
      { "id": "spacer", "enabled": true },
      { "id": "activeWindow", "enabled": true },
      { "id": "media", "enabled": true },
      { "id": "clock", "enabled": true },
      { "id": "spacer", "enabled": true },
      { "id": "system", "enabled": true },
      { "id": "power", "enabled": true },
      { "id": "statusIcons", "enabled": true },
      { "id": "tray", "enabled": true },
      { "id": "appearance", "enabled": true },
      { "id": "quickUtilities", "enabled": true },
      { "id": "nexus", "enabled": true },
      { "id": "notifications", "enabled": true }
    ]
  }
}
```

`general.logo` overrides the OS logo button icon. Use a theme icon name or an
absolute image path. `general.showOverFullscreen` keeps distraction-heavy appbar
modules visible even while a fullscreen window is active.
`general.apps` controls the external programs opened from appbar dropdowns and
quick utilities. The first installed candidate is used where detection is
needed. `playback` is shown in the media dropdown as an external player launcher
when one of the configured candidates is installed.

`appearance` controls shell-wide motion and surface treatment:

- `anim.enabled`: disable to remove appbar, dropdown, workspace, and OSD motion.
- `anim.durationScale`: multiply animation durations; values below `1` are
  faster, values above `1` are slower.
- `transparency.enabled`: enable opacity overrides for the appbar, dropdowns,
  and OSD surfaces.
- `transparency.barOpacity`, `panelOpacity`, `osdOpacity`: opacity values from
  `0.15` to `1`.
- `rounding`: global radius scale from squared-off `0` to extra rounded `2`.
- `deformScale`: additional appbar/dropdown radius multiplier. This mirrors the
  Caelestia setting at a local scale rather than implementing token-level shape
  deformation.
- `spacing.scale`: global spacing scale for top appbar module gaps.
- `padding.scale`: global padding scale for top appbar edge padding.
- `font.scale`: manual global text scale for the appbar and dropdown shell
  surfaces.
- `font.scaleWithMonitor`: when enabled, text size is additionally compensated
  from the monitor `devicePixelRatio`. This matters on 4K Hyprland outputs with
  scale values such as `1.5`, where uncorrected QML `pixelSize` values look
  visually smaller than expected.
- `font.monitorScaleWeight`: how strongly monitor scale affects text. The
  default `1` makes a `1.5` monitor scale use `1.5x` text scale. Lower this if
  a specific monitor feels too large.
- `font.clock`, `font.workspaces`: optional font family overrides for the clock
  and workspace labels.
- `font.label`, `font.body`, `font.title`: optional `{ "family": "..." }` and
  size tokens. The appbar consumes these tokens for top-bar labels, status
  pills, workspaces, tray menus, quick utility rows, calendar text, power menus,
  and compact media or active-window text.

This is intentionally a top-level option. Per-monitor config can change which
bar modules appear, but visual motion/transparency stays consistent across
monitors.

`bar.entries` accepts Caelestia-style entry toggles. `spacer` entries split the
appbar into left, center, and right sections. The local shell applies that
section placement to `activeWindow`, `media`, `clock`, `system`, `power`,
`statusIcons`, `tray`, `appearance`, `quickUtilities`, `nexus`, and
`notifications`. Omitted entries are hidden when an entries list is provided.
The `logo`, `dashboard`, `workspaces`, and special-workspace indicator still
stay in the left cluster because they are Hyprland navigation primitives.

`bar.persistent` keeps the appbar visible and reserves screen space with an
exclusive zone. Setting `persistent` to `false` and `showOnHover` to `true`
creates an auto-hide bar: a thin top-edge reveal zone shows the appbar on hover,
and open dropdowns keep it visible until closed.
`bar.dragThreshold` controls interaction sensitivity for the appbar: it scales
the auto-hide reveal zone and the workspace hover intent delay.

`bar.font` controls only the visible top appbar text, separate from dropdown
content:

- `scale`: multiplier applied to the top appbar font values.
- `labelSize`: workspace/status/icon fallback label size.
- `bodySize`: active-window, media, and system value text size.
- `clockSize`: top-bar clock size.
- `badgeSize`: notification count and compact overflow badge size.
- `workspaceIconSize`: workspace app icon fallback text size.

`panel.font` controls dropdown and menu surfaces such as power, media, audio,
network, Bluetooth, tray menu rows, quick utilities, and dashboard panels:

- `scale`: multiplier applied to dropdown/menu text.
- `titleSize`: section titles and primary row titles.
- `labelSize`: button labels and menu row labels.
- `bodySize`: normal detail text.
- `metaSize`: secondary metadata and compact hints.
- `heroSize`: large summary values in resource/media panels.
- `iconSize`: large text fallback glyphs used when artwork/icon images are
  missing.

`calendar.font` controls only the calendar dropdown:

- `scale`: multiplier applied to calendar text.
- `labelSize`: weekday and month picker button text.
- `titleSize`: year/month picker title text.
- `daySize`: date number size inside the month grid.
- `detailSize`: selected-day detail line below the calendar grid.

Other surface font tokens:

- `launcher.font`: app launcher input, result title/body, hints, and app id
  metadata.
- `notifs.font`: notification center and snackbar/toast title, body, metadata,
  and icon fallback text.
- `keybindHelp.font`: searchable shortcut overlay title, labels, rows, and
  metadata.
- `submap.font`: resize/music mode indicator icon, label, and escape hint.
- `background.desktopClock.font`: optional desktop clock time/date text.

Qt Quick still applies font sizes on individual `Text`/`TextInput` elements via
`font.pixelSize`; these values are now bound to semantic tokens instead of raw
numbers, so one config change propagates through the relevant surface.

`bar.scrollActions` controls mouse-wheel behavior on appbar modules:

- `workspaces`: scroll over the workspace pill to switch workspaces.
- `volume`: scroll over the audio status pill to change volume.
- `brightness`: scroll over the brightness status pill to change backlight.

`bar.popouts` controls which appbar modules open dropdowns:

- `activeWindow`: active window detail/actions dropdown.
- `tray`: StatusNotifier tray menu popouts. If disabled, tray icons are
  activated directly.
- `statusIcons`: audio, network, Bluetooth, keyboard, brightness, privacy,
  updates, weather, idle, and temperature status dropdowns.

`bar.workspaces.shown` controls how many workspace buttons appear when the
workspace pill expands. It accepts values from `1` to `20`; the default is `10`.
Additional workspace preferences:

- `label`: replace the default workspace number with a custom label. Leave it
  empty to keep the workspace number.
- `occupiedLabel`: label for occupied workspaces. Empty falls back to `label`
  or the workspace number.
- `activeLabel`: label for the focused workspace. Empty falls back to
  `occupiedLabel`, `label`, or the workspace number.
- `maxWindowIcons`: cap the number of app icons shown inside each expanded
  workspace pill; extra windows are shown as an overflow count.
- `activeIndicator`: highlight the active workspace with the accent fill.
- `activeTrail`: show a subtle accent trail behind expanded workspace buttons.
- `wheelThreshold`: accumulated wheel delta required before switching one
  workspace. Increase it if scrolling still moves too quickly.
- `wheelCooldownMs`: minimum delay between workspace wheel switches.
- `wheelMaxSteps`: maximum number of workspaces a strong wheel gesture can move
  at once.
- `perMonitorWorkspaces`: when enabled, workspace occupancy counts only include
  workspaces reported on the current monitor.
- `occupiedBg`: show a subtle background/border for occupied workspaces.
- `showWindows`: show small app icons for windows inside expanded workspace
  pills.
- `showWindowsOnSpecialWorkspaces`: append a window-count suffix to the special
  workspace chip.
- `capitalisation`: label casing for custom workspace labels. Supported values:
  `preserve`, `upper`, `lower`, and `title`.
- `specialWorkspaceIcons`: map special workspace names to icons. Example:
  `[{"name": "music", "icon": "media-playback-start-symbolic"}]`.
- `windowIcons`: map active window and workspace window class/title regexes to
  icons. Example:
  `[{"regex": "spotify|youtube", "icon": "media-playback-start-symbolic"}]`.

Active window preferences live under `bar.activeWindow`:

- `compact`: collapse the active window module to an icon-sized chip.
- `showOnHover`: when `compact` is enabled, expand the title on hover.
- `inverted`: use the accent color as the active window module background.

Dashboard preferences live under `dashboard`:

```json
{
  "dashboard": {
    "enabled": true,
    "showOnHover": false,
    "profileImage": "",
    "showDashboard": true,
    "showMedia": true,
    "showPerformance": true,
    "showWeather": true,
    "mediaUpdateInterval": 5000,
    "resourceUpdateInterval": 3000,
    "performance": {
      "showBattery": true,
      "showGpu": true,
      "showCpu": true,
      "showMemory": true,
      "showStorage": true,
      "showNetwork": true,
      "showTemperature": true
    }
  }
}
```

The appbar dashboard is a compact local equivalent of Caelestia's dashboard
surface. It keeps the interaction lightweight by showing profile/uptime,
resource metrics, currently playing media, performance meters, and weather in a
single dropdown instead of a full dashboard window.
`dashboard.showOnHover` opens that dropdown when the appbar dashboard button is
hovered; click-to-toggle remains available either way.
`dashboard.resourceUpdateInterval` aliases the appbar resource polling interval,
and `dashboard.mediaUpdateInterval` controls local media lyrics polling. These
names match Caelestia's config model; `services.intervals.*` can still be used
for the broader local polling groups.
`dashboard.performance.showCpu`, `showMemory`, `showGpu`, `showStorage`,
`showNetwork`, `showBattery`, and `showTemperature` control which resource
tiles and meters appear in the dashboard dropdown.
The profile picture uses `dashboard.profileImage` when set, otherwise it reads
`~/.face` like Caelestia. If no image exists, the dashboard falls back to the
user initial. Click the avatar or the `Set profile picture` action in the
dashboard to choose an image and copy it to `~/.face`.

Nexus preferences live under `nexus`:

```json
{
  "nexus": {
    "enabled": true,
    "networkRescanInterval": 120000
  }
}
```

The local Nexus surface is a compact network overview opened from the appbar. It
shows the active connection, traffic, Wi-Fi signal, nearby Wi-Fi networks, saved
NetworkManager connections, and shortcuts to `nm-connection-editor` or `nmtui`.

Sidebar preferences live under `sidebar`:

```json
{
  "sidebar": {
    "enabled": true,
    "showOnHover": false,
    "minHoverThreshold": 12,
    "width": 390,
    "height": 560,
    "topMargin": 52,
    "rightMargin": 12
  }
}
```

The notification center acts as the local sidebar surface. It is opened by the
appbar notification button, `qs ipc call notifications toggle`, or
`qs ipc call sidebar toggle`. When `showOnHover` is enabled, a thin right-edge
reveal zone opens it on pointer hover.

Background preferences live under `background`:

```json
{
  "background": {
    "enabled": false,
    "wallpaperEnabled": true,
    "desktopClock": {
      "enabled": false,
      "scale": 1.0,
      "position": "bottom-right",
      "invertColors": false,
      "font": {
        "timeSize": 62,
        "dateSize": 18
      },
      "background": {
        "enabled": false,
        "opacity": 0.22,
        "blur": false
      }
    },
    "visualiser": {
      "enabled": false,
      "opacity": 0.26,
      "height": 150
    }
  },
  "services": {
    "visualiserBars": 42
  }
}
```

The background layer is disabled by default so it cannot interfere with window
stacking on a new install. When enabled, it draws a non-interactive desktop
clock and a lightweight theme-coloured animated visualiser. This is a local
visual equivalent, not Caelestia's audio FFT visualiser backend.

Clock preferences live under `bar.clock`:

```json
{
  "bar": {
    "clock": {
      "enabled": true,
      "background": true,
      "showDate": true,
      "showIcon": false
    }
  }
}
```

`bar.clock.background` controls whether the clock keeps its rounded module
background or appears as text/icon only.

To hide the appbar on a monitor, either list the screen name in
`bar.excludedScreens` or use a monitor override:

```json
{
  "bar": {
    "excludedScreens": ["DP-1"]
  },
  "monitors": {
    "DP-1": {
      "bar": {
        "enabled": false
      }
    }
  }
}
```

Caelestia-style per-monitor files are also supported for screen-bound surfaces
such as the appbar and background layer:

```text
~/.config/dotfiles/monitors/<screen-name>/quickshell.json
```

For example:

```json
{
  "bar": {
    "enabled": false
  },
  "background": {
    "desktopClock": {
      "enabled": true,
      "position": "bottom-right"
    }
  }
}
```

Per-monitor values are read in this order:

1. `~/.config/dotfiles/monitors/<screen-name>/quickshell.json`
2. `monitors.<screen-name>` inside `~/.config/dotfiles/quickshell.json`
3. global values inside `~/.config/dotfiles/quickshell.json`

Status items can be toggled under `bar.status`, including `audio`,
`microphone`, `privacy`, `keyboard`, `lockStatus`, `network`, `weather`,
`bluetooth`, `brightness`, `idleInhibit`, `updates`, and `temperature`.
Caelestia-style status keys are also accepted for common items:
`showAudio`, `showMicrophone`, `showKbLayout`, `showNetwork`, `showWifi`,
`showBluetooth`, `showBattery`, and `showLockStatus`.
`showWifi` controls Wi-Fi status. Wired Ethernet is intentionally not surfaced
as a separate appbar network item so it does not duplicate the Wi-Fi controls.
`showNetwork` is retained for offline/network fallback compatibility.
`showBattery` only controls the laptop battery pill; the power profile pill and
power menu are controlled by the `power` bar entry.
If every status item is disabled or currently unavailable, the `statusIcons`
entry hides itself instead of leaving an empty rounded group on the appbar.
Quick Utilities rows can be toggled under `utilities.quickToggles`, including
`wifi`, `bluetooth`, `mic`, `privacy`, `dnd`, `idleInhibit`, `gameMode`,
`weather`, `vpn`, `clipboard`, `wallpaper`, `recording`,
`screenshotArea`, `screenshotScreen`, `explorer`, and `settings`.
Both object syntax (`{"wifi": true}`) and Caelestia-style array syntax
(`[{"id": "wifi", "enabled": true}]`) are supported.

VPN quick utility settings live under `utilities.vpn`. The first enabled
provider is shown in the quick utilities dropdown. Supported provider names are
`nordvpn`, `wireguard`/`wg`, and NetworkManager connection names through
`nmcli`:

```json
{
  "utilities": {
    "vpn": {
      "enabled": true,
      "provider": [
        { "name": "nordvpn", "displayName": "NordVPN", "enabled": true },
        { "name": "wireguard", "interface": "wg0", "displayName": "WireGuard", "enabled": false },
        { "name": "work-vpn", "interface": "work-vpn", "displayName": "Work VPN", "enabled": false }
      ]
    }
  }
}
```

Tray preferences live under `bar.tray`:

- `background`: show the rounded tray group background and border.
- `compact`: reduce tray button size and spacing.
- `recolour`: tint tray icons with the current theme foreground. Keep this
  disabled for branded app icons such as NordVPN.
- `iconSize`: tray icon size from `12` to `24`.
- `preferNativeMenu`: use Quickshell's native tray menu renderer directly
  instead of the themed QML menu. This is useful for tray apps whose DBus menu
  implementation does not expose children reliably.
- `nativeMenuFallback`: keep the themed QML tray menu by default, but fall back
  to the native renderer when the first opened menu has no exposed entries.
- `nativeSubmenuFallback`: allow native fallback for nested tray submenus.
  This is disabled by default so nested menus do not visually jump back to the
  toolkit/system menu style.
- `hiddenIcons`: lower-case match list for tray item id, title, icon name, or
  tooltip. For example, `["fcitx"]` hides the fcitx tray entry if the separate
  keyboard status chip is preferred.
- `iconSubs`: map tray item id/title/icon names to replacement icon names.
  Both object syntax (`{ "fcitx": "input-keyboard-symbolic" }`) and
  Caelestia-style array syntax
  (`[{ "from": "fcitx", "to": "input-keyboard-symbolic" }]`) are supported.

Launcher preferences can be set under `launcher`:

```json
{
  "launcher": {
    "showOnHover": false,
    "minHoverThreshold": 12,
    "maxShown": 80,
    "maxWallpapers": 9,
    "specialPrefix": "@",
    "actionPrefix": ">",
    "font": {
      "scale": 1,
      "titleSize": 9,
      "bodySize": 8,
      "inputSize": 10,
      "hintSize": 9,
      "metaSize": 7
    },
    "enableDangerousActions": true,
    "vimKeybinds": true,
    "favouriteApps": ["firefox", "kitty"],
    "hiddenApps": ["avahi", "assistant"],
    "useFuzzy": {
      "apps": false,
      "actions": false,
      "schemes": false,
      "variants": false,
      "wallpapers": false
    },
    "actions": [
      {
        "name": "Settings",
        "icon": "preferences-system-symbolic",
        "description": "Open system settings",
        "command": "if command -v gnome-control-center >/dev/null 2>&1; then gnome-control-center; elif command -v systemsettings >/dev/null 2>&1; then systemsettings; fi",
        "enabled": true,
        "dangerous": false
      }
    ]
  }
}
```

- `showOnHover`: reveal the launcher from a thin left-edge hover zone on the
  focused monitor.
- `minHoverThreshold`: width of the launcher edge-hover zone in pixels. If this
  is omitted, `launcher.dragThreshold` is accepted as a Caelestia-style alias.
- `maxShown`: maximum visible launcher results retained in the model, from `1`
  to `80`.
- `maxWallpapers`: maximum wallpaper results added to the launcher.
- `specialPrefix`: prefix for color schemes and wallpapers. The default is
  `@`.
- `actionPrefix`: prefix for command actions. The default is `>`.
- `enableDangerousActions`: show logout, reboot, and shutdown actions in the
  launcher.
- `vimKeybinds`: allow `Ctrl+J` and `Ctrl+K` to move the launcher selection
  without stealing normal `j`/`k` search input. Arrow keys always work.
- `favouriteApps`: app names, desktop IDs, or comments that should be sorted to
  the top of app results.
- `hiddenApps`: app names, desktop IDs, or comments that should be removed from
  launcher app results.
- `useFuzzy`: enable simple ordered-character fuzzy matching for apps, actions,
  schemes, variants, or wallpapers.
- `actions`: extra command actions added before the built-in launcher actions.
  `command` can be a shell string or a command array. Caelestia-style
  `["autocomplete", "scheme"]`, `["autocomplete", "variant"]`,
  `["autocomplete", "wallpaper"]`, `["setMode", "light"|"dark"]`, and
  `["caelestia", "wallpaper", "-r"]` commands are translated to this shell's
  native launcher/theme/wallpaper behavior.

Service preferences can be set under `services`:

- `weatherLocation`: location used by the weather status pill, such as `Seoul`.
- `useFahrenheit`: request Fahrenheit units for the weather status pill.
- `useFahrenheitPerformance`: show appbar/system temperature in Fahrenheit.
- `gpuType`: force GPU detection order. Supported values are empty auto-detect,
  `nvidia`, `amd`, and `intel`.
- `useTwelveHourClock`: switch the appbar clock to 12-hour time.
- `audioIncrement`: mouse-wheel volume step, from `0.01` to `0.5`.
- `brightnessIncrement`: mouse-wheel brightness step, from `0.01` to `0.5`.
- `maxVolume`: PipeWire volume cap used by sliders and `wpctl -l`, from `0.1`
  to `2.0`.
- `visualiserBars`: number of bars used by the optional background visualiser.
- `smartScheme`: optional wallpaper-to-theme integration. `false` disables it.
  `auto`, `dynamic`, or `true` uses ImageMagick `magick` to choose light/dark
  mode from wallpaper brightness. `light` or `dark` forces that mode. Any other
  string is treated as a color scheme name. Object syntax supports
  `{ "colorScheme": "catppuccin", "mode": "dark" }` or a custom `command`;
  the applied wallpaper path is exposed as `SMART_WALLPAPER`.
- `defaultPlayer`: preferred MPRIS player match text, such as `spotify`,
  `youtube`, or `chrome`.
- `playerAliases`: custom MPRIS display names and priorities. Example:
  `[{"match": "com.github.th_ch.youtube_music", "label": "YT Music", "priority": 120}]`.
- `lyricsBackend`: `Local` to show local `.lrc` or `.txt` lyrics in the media
  dropdown, or `None` to disable lyrics.
- `intervals`: appbar polling intervals in milliseconds. Supported keys:
  `resources` for CPU/memory/network traffic, `slowResources` for storage and
  saved device lists, `status` for network/Bluetooth/backlight/VPN/temperature,
  `fastStatus` for volume and fullscreen state, `tools` for external command
  detection, `media` for local lyrics/media polling, `weather`, `updates`, and
  `config`.

Path preferences can be set under `paths`:

- `wallpaperDir`: directory used by the launcher and quick utility wallpaper
  actions. The default is `~/Pictures/Wallpapers`.
- `lyricsDir`: directory scanned for local `.lrc` or `.txt` lyrics. File names
  are matched against the current MPRIS artist/title.

Battery warning preferences can be set under `general.battery`:

```json
{
  "general": {
    "battery": {
      "warnLevels": [
        {
          "level": 20,
          "title": "Low battery",
          "message": "You might want to plug in a charger",
          "icon": "battery-caution-symbolic"
        },
        {
          "level": 5,
          "title": "Critical battery",
          "message": "Suspending soon unless power is connected",
          "icon": "battery-empty-symbolic",
          "critical": true
        }
      ],
      "criticalLevel": 3,
      "criticalAction": "none"
    }
  }
}
```

Warnings are shown once per descending level while the battery is discharging,
and reset when charging starts. `criticalAction` can be `none`, `suspend`,
`hibernate`, `suspendThenHibernate`, or `poweroff`.

OSD preferences can be set under `osd`:

- `enabled`: enable or disable all Quickshell OSD feedback.
- `hideDelay`: OSD hide delay in milliseconds.
- `enableBrightness`: show brightness OSD feedback.
- `enableMicrophone`: show microphone mute OSD feedback.

Session preferences can be set under `session`:

```json
{
  "session": {
    "enabled": true,
    "icons": {
      "lock": "system-lock-screen-symbolic",
      "logout": "system-log-out-symbolic",
      "shutdown": "system-shutdown-symbolic",
      "hibernate": "media-playback-pause-symbolic",
      "reboot": "system-reboot-symbolic"
    },
    "commands": {
      "lock": "if command -v hyprlock >/dev/null 2>&1; then pidof hyprlock >/dev/null 2>&1 || hyprlock; else loginctl lock-session; fi",
      "logout": ["logout"],
      "shutdown": ["poweroff"],
      "hibernate": ["hibernate"],
      "reboot": ["reboot"]
    }
  }
}
```

The appbar power dropdown reads `session.commands` and `session.icons` for lock,
logout, shutdown, hibernate, and reboot. Commands can be shell strings or
Caelestia-style command arrays. Known array shortcuts such as `["logout"]`,
`["poweroff"]`, `["hibernate"]`, and `["reboot"]` are mapped to the local
Hyprland/systemd commands.

Lock preferences can also be set under `lock`:

```json
{
  "lock": {
    "enabled": true,
    "useFprint": false,
    "commands": {
      "lock": "if command -v hyprlock >/dev/null 2>&1; then pidof hyprlock >/dev/null 2>&1 || hyprlock; else loginctl lock-session; fi"
    }
  }
}
```

`lock.commands.lock` has priority over `session.commands.lock` and is used by
both the appbar power dropdown and the launcher Lock action.

## Quick Utilities

The quick utilities button on the right side of the bar provides:

- notification DND toggle
- idle inhibit toggle through `systemd-inhibit`
- Hyprland game mode toggle that disables animations and blur until disabled
- compact Wi-Fi, Bluetooth, and microphone quick toggles when matching session
  services are available
- package update launcher through `paru -Syu` when updates are pending
- VPN connect/disconnect for the configured `utilities.vpn` provider
- file manager launcher through the configured `general.apps.explorer`
- clipboard history picker backed by `cliphist` and `wl-copy`
- random wallpaper switcher when `swww` is installed, or when `hyprpaper` is
  running and controllable through `hyprctl`
- screen recording toggle when `wf-recorder` is installed; `slurp` is used for
  region selection when available
- area screenshot through `grim` and `slurp`
- full-screen screenshot through `grim`
- system settings launcher through the configured `general.apps.settings`

Screenshots are saved to:

```text
~/Pictures/Screenshots
```

Screen recordings are saved to:

```text
~/Videos/Recordings
```

## Theme Model

Themes are split into two concepts:

- `mode`: light or dark. This controls GTK/Chrome dark preference and lets the
  Appearance picker group themes by light/dark mode.
- `colorScheme`: the palette family, such as `catppuccin`, `rose-pine`,
  `solarized`, or `tokyonight`.
- `variant`: the concrete palette variant inside that family, such as
  `mocha`, `latte`, `dawn`, `dark`, or `light`.
- `name`: the concrete theme id passed to `apply-theme.sh`, such as
  `catppuccin-mocha` or `solarized-light`.

The Appearance dropdown has direct Light/Dark buttons. They keep the current
`colorScheme` family when a matching variant exists, for example
`catppuccin-mocha` <-> `catppuccin-latte` and
`solarized-dark` <-> `solarized-light`. Dark-only palettes leave the unavailable
mode disabled.

The generated values are applied to Quickshell, Hyprland borders, Kitty,
Alacritty, GTK, and Chrome flags.

Run:

```sh
./apply-theme.sh --list
./apply-theme.sh --color-scheme catppuccin --mode light
./apply-theme.sh --mode dark
```

to see or apply the available color schemes and their mode. The top-bar
Appearance dropdown exposes the same model: `Mode` is only `dark`/`light`, and
`Color scheme` is the palette family.

Random wallpaper reads images from `paths.wallpaperDir`:

```text
~/Pictures/Wallpapers
```

Supported file extensions are `jpg`, `jpeg`, `png`, and `webp`. The menu item
is hidden when no supported wallpaper backend or no image files are found.

Weather is disabled by default. To enable the top-bar weather pill, set
`services.weatherLocation`, for example:

```json
{
  "services": {
    "weatherLocation": "Seoul"
  }
}
```

As a fallback, the bar also reads:

```text
~/.config/dotfiles/weather-location
```

with one location on the first line, for example:

```text
Seoul
```

The DND state is stored outside the repository at:

```text
~/.local/state/dotfiles/quickshell-dnd.enabled
```

Idle inhibit stores its helper process id outside the repository at:

```text
~/.local/state/dotfiles/quickshell-idle-inhibit.pid
```

Game mode stores its enabled flag outside the repository at:

```text
~/.local/state/dotfiles/quickshell-game-mode.enabled
```

When enabled, it applies these runtime Hyprland overrides:

```sh
hyprctl keyword animations:enabled 0
hyprctl keyword decoration:blur:enabled 0
```

When disabled, it runs `hyprctl reload` so the normal Hyprland config is
restored.

## Launcher

The launcher reads visible `.desktop` applications from Quickshell
`DesktopEntries` and also exposes a small set of Caelestia-style command
actions, color scheme entries, and wallpaper entries.

- `SUPER+Space` / `CTRL+Space`: toggle launcher
- type text: filter by app name, description, or desktop id
- type the configured action prefix, default `>`: filter command actions only
- type the configured special prefix, default `@`: filter special entries,
  including color schemes and wallpapers
- type `calc 1+2` or `=1+2`: calculate with `qalc`; selecting the result
  copies it with `wl-copy`
- `Down`: move selection down
- `Up`: move selection up
- `Ctrl+J` / `Ctrl+K`: move selection when `launcher.vimKeybinds` is enabled
- `Enter`: launch selected app
- `Esc`: close
- `R` button: refresh the in-memory application list

The launcher is fixed width, shows the app icon on the left, and shows the
desktop id on the right so Chrome-installed web apps are easier to identify
when their `.desktop` files are visible to the system.

Built-in launcher actions include calculator, lock, screenshots, settings,
audio controls, network settings, random wallpaper, notification server toggle,
light/dark mode, suspend, logout, reboot, and shutdown.
Color scheme results call `apply-theme.sh`, so they update Hyprland,
Quickshell, GTK, Chrome flags, Kitty, and Alacritty through the shared theme
pipeline.
Wallpaper results are read from `paths.wallpaperDir` when `swww` or a running
`hyprpaper` backend is available.

## Picker IPC

Caelestia-style picker IPC is available through Quickshell:

```sh
qs ipc call picker open
qs ipc call picker openFreeze
```

By default these commands use `hyprpicker` when it is installed and show a
notification otherwise. Override the commands in
`~/.config/dotfiles/quickshell.json`:

```json
{
  "picker": {
    "commands": {
      "open": "hyprpicker -a",
      "openFreeze": "hyprpicker -a -r"
    }
  }
}
```

## Caelestia-Compatible IPC

The shell exposes compatibility targets for scripts and Hyprland keybinds that
expect common Caelestia shell IPC names:

```sh
qs-shell -s
qs-shell mpris getActive trackTitle
qs-shell drawers toggle media
qs ipc call notifs clear
qs ipc call drawers list
qs ipc call drawers toggle media
qs ipc call drawers toggle calendar
qs ipc call mpris playPause
qs ipc call mpris next
qs ipc call mpris previous
qs ipc call mpris getActive trackTitle
qs ipc call mpris list
qs ipc call wallpaper list
qs ipc call wallpaper get
qs ipc call wallpaper set /path/to/image.png
qs ipc call lock lock
```

`mpris` commands operate on the configured `services.defaultPlayer` when it is
set, then fall back to the currently playing player or the first available
player. `wallpaper` uses `swww` when available and otherwise falls back to a
running `hyprpaper` instance. `drawers` opens appbar dropdowns on the currently
focused monitor.

## Notifications

Quickshell notifications are optional because only one process can own
`org.freedesktop.Notifications` at a time.

```sh
qs-notifications status
qs-notifications enable
qs-notifications disable
```

- `enable`: masks legacy notification daemons, writes a user-state flag, and
  restarts Quickshell with `NotificationServer` active.
- `disable`: turns the flag off and restarts Quickshell without starting an
  external notification daemon.

The flag is stored outside the repository at:

```text
~/.local/state/dotfiles/quickshell-notifications.enabled
```

The current notification history count is mirrored for the top-bar badge at:

```text
~/.local/state/dotfiles/quickshell-notification-count
```

When DND is enabled from the quick utilities dropdown, notifications are still
stored in the notification center history, but toast popups are not shown.

Notification behavior can be tuned in `~/.config/dotfiles/quickshell.json`:

```json
{
  "notifs": {
    "enabled": true,
    "expire": true,
    "fullscreen": "on",
    "defaultExpireTimeout": 5000,
    "fullscreenExpireTimeout": 2000,
    "actionOnClick": false,
    "font": {
      "scale": 1,
      "titleSize": 11,
      "labelSize": 9,
      "bodySize": 8,
      "metaSize": 7,
      "iconSize": 11
    }
  },
  "utilities": {
    "enabled": true,
    "maxToasts": 4,
    "toasts": {
      "enabled": true,
      "fullscreen": "off"
    }
  }
}
```

- `notifs.fullscreen`: `on`, `off`, or `critical`
- `utilities.toasts.fullscreen`: `on`, `off`, or `critical`
- `notifs.actionOnClick`: invokes the first notification action when the toast
  background is clicked

## Active Window

The active window dropdown shows the current title, class, and workspace, then
offers quick Hyprland actions:

- toggle floating
- toggle fullscreen
- pin
- screenshot active window through `grim` and `swappy`
- close active window
