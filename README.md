# dotfiles

Personal Linux desktop configuration managed as one repository.

## Included

- `hypr`: Hyprland configuration
- `nvim`: Neovim configuration
- `alacritty`: Alacritty terminal configuration
- `kitty`: Kitty terminal configuration
- `starship`: Starship prompt configuration
- `zsh`: Zsh, Oh My Zsh plugins, and prompt configuration
- `quickshell`: QtQuick/QML desktop shell for Hyprland
- `herdr`: terminal workspace manager configuration
- `themes`: shared color schemes for Hyprland, Quickshell, Kitty, Alacritty, GTK, and Chrome

## Layout

```text
dotfiles/
├── config/
│   ├── hypr/
│   ├── nvim/
│   ├── alacritty/
│   ├── kitty/
│   ├── quickshell/
│   ├── starship/
│   ├── herdr/
│   └── zsh/
├── home/
│   ├── .zshenv
│   └── .p10k.zsh
├── themes/
│   ├── default/
│   └── graphite/
├── scripts/
│   └── remove-kde-stack.sh
├── apply-theme.sh
├── install.sh
└── backup.sh
```

## Backup Current Configs Into This Repo

```sh
./backup.sh
```

This copies matching directories from `~/.config` into `./config`.

## Install

```sh
./install.sh
```

The installer shows a selection menu. Choose numbers or names separated by
spaces:

```text
1 3 zsh
hypr nvim
all
```

You can also pass selections directly:

```sh
./install.sh hypr kitty
./install.sh all
```

Selected entries install their required Arch packages when `pacman` is
available and move existing managed paths to a timestamped backup directory.
Packages outside the enabled repositories are installed with `paru` or `yay`
when either helper is present.

Install modes are split by how often the target writes machine-local state:

- `hypr`, `nvim`, and `quickshell` are linked as full config directories.
- `herdr` links only `~/.config/herdr/config.toml`; runtime logs, sockets, and
  sessions stay local.
- `zsh` is copied, while machine-specific environment variables stay in
  `~/.config/zsh.local.zsh`.
- Other selected config directories are copied.

To skip package installation and only install files:

```sh
DOTFILES_SKIP_PACKAGES=1 ./install.sh hypr
```

The `hypr` entry links `~/.config/hypr` to `config/hypr`, then creates
machine-local files under `~/.config/dotfiles/hypr` from examples only when
they do not already exist.

The `zsh` entry installs the XDG-style zsh layout by copying `~/.config/zsh`,
`~/.zshenv`, and `~/.p10k.zsh`. The copied `.zshenv` points zsh at
`~/.config/zsh`. Machine-specific zsh settings live in
`~/.config/zsh.local.zsh`, which is not managed by the installer.

## Color Schemes

Shared desktop color schemes are managed from `themes/<name>/theme.conf`.
Each scheme has two separate concepts:

- `THEME_MODE`: broad appearance mode, either `dark` or `light`
- color scheme: the palette family, such as `default`, `catppuccin`,
  `rose-pine`, or `solarized`
- variant: the concrete palette entry, such as `dark`, `light`, `mocha`,
  `latte`, or `dawn`

Apply a color scheme from the repository root:

```sh
./apply-theme.sh --list
./apply-theme.sh default
./apply-theme.sh graphite
./apply-theme.sh catppuccin-mocha
./apply-theme.sh --color-scheme catppuccin --mode light
./apply-theme.sh --colorScheme solarized --mode dark
```

The script generates theme files for:

- Hyprland window borders: `config/hypr/theme/hyprland.conf`
- Quickshell shell: `config/quickshell/Theme.js`
- Kitty colors: `config/kitty/theme.conf`
- Alacritty colors: `config/hypr/theme/alacritty.toml`
- GTK colors: `config/gtk-3.0`, `config/gtk-4.0`
- Chrome dark/light flags: `config/chrome-flags.conf`

Hyprland sources the generated file from `hyprland.conf`. Quickshell imports the
generated `Theme.js`, which exposes both `Theme.mode` and
`Theme.colorScheme`. Kitty includes `theme.conf` from `kitty.conf`, and
Alacritty imports the generated TOML from `alacritty.toml`.

`apply-theme.sh` also ensures generated GTK, Kitty, and Chrome flag files are
present under `~/.config` when they are missing. It updates GNOME/GTK
`color-scheme`, reloads Hyprland, tries to reload open Kitty windows, and
restarts Quickshell when it is already running.

## System Cleanup

`scripts/remove-kde-stack.sh` removes the KDE/Plasma desktop stack after marking
`pipewire-pulse`, `mpv`, and `noto-fonts-emoji` as explicit packages so they are
kept for the Hyprland setup.

## Quickshell Desktop Shell

The active Hyprland shell is now Quickshell:

```text
config/quickshell/shell.qml
```

It currently provides:

- top status bar
- app launcher on `SUPER+Space` and `CTRL+Space`
- app search with keyboard selection
- Hyprland workspace/window/clock widgets
- MPRIS media dropdown
- PipeWire volume and mute controls
- system resource, calendar, power, and tray dropdowns
- dark/light color scheme picker from the top bar
- keybind help overlay on `SUPER+?`
- Hyprland submap mode indicator
- optional Quickshell notification/snackbar server via `qs-notifications`
- `qs-shell` IPC wrapper for appbar targets such as `mpris`, `drawers`,
  `notifs`, `picker`, `wallpaper`, and `lock`

Active tray items are now rendered by Quickshell directly. Waybar is not used as
a fallback tray host.

## Per-Config Docs

Each config directory has its own README with required packages and optional
dependencies:

- `config/hypr/README.md`
- `config/quickshell/README.md`
- `config/waybar/README.md`
- `config/yazi/README.md`
- `config/nvim/README.md`
- `config/alacritty/README.md`
- `config/kitty/README.md`
- `config/starship/README.md`
- `config/herdr/README.md`
- `config/zsh/README.md`

## Git

```sh
git status
git add .
git commit -m "Initial dotfiles"
```
