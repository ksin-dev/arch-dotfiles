# Color Schemes

Shared desktop color palettes for dark and light desktop color schemes.

The setup separates appearance mode from the selected palette:

- `THEME_MODE`: broad `dark` or `light` mode used for GTK/Chrome preference
  flags and Quickshell grouping
- color scheme: the concrete palette name, matching the directory under
  `themes/`

Each theme lives in:

```text
themes/<name>/theme.conf
```

Apply a color scheme from the repository root or from the Quickshell top-bar
`Appearance` picker. The picker separates the concepts visually:

- `Mode`: `dark` or `light`
- `Color scheme`: the selected palette family, such as `default`,
  `graphite`, `catppuccin`, `rose-pine`, or `solarized`
- `Variant`: the concrete entry inside that family, such as `mocha`,
  `latte`, `dawn`, `dark`, or `light`

Schemes are grouped by `THEME_MODE` as `dark` or `light`, while
`Theme.colorScheme` stores the selected palette family:

```sh
./apply-theme.sh --list
./apply-theme.sh default
./apply-theme.sh default-light
./apply-theme.sh graphite
./apply-theme.sh catppuccin-mocha
./apply-theme.sh --color-scheme catppuccin --mode light
./apply-theme.sh --colorScheme catppuccin --mode light
./apply-theme.sh --color-scheme solarized --mode dark
./apply-theme.sh --mode light
```

When only `--mode` is provided, the script keeps the current `colorScheme`
family if a matching light/dark variant exists. When only `--color-scheme` is
provided, it keeps the current mode when possible and falls back to the first
matching variant.

## Generated Targets

`apply-theme.sh` writes:

- `config/hypr/theme/hyprland.conf`: Hyprland active/inactive border colors
- `config/hypr/theme/alacritty.toml`: Alacritty color palette
- `config/kitty/theme.conf`: Kitty color palette
- `config/quickshell/Theme.js`: Quickshell shell color tokens, including
  `mode` and `colorScheme`
- `config/gtk-3.0/settings.ini` and `gtk.css`: GTK3 theme colors
- `config/gtk-4.0/settings.ini` and `gtk.css`: GTK4 theme colors
- `config/chrome-flags.conf`: Chrome dark/light behavior flags
- `config/hypr/theme/current`: current theme name

The script reloads Hyprland when `hyprctl` is available and restarts running
Quickshell shell instances.

## Included Schemes

- `default`
- `default-light`
- `graphite`
- `catppuccin-mocha`
- `catppuccin-latte`
- `rose-pine`
- `rose-pine-dawn`
- `nord`
- `dracula`
- `solarized-dark`
- `solarized-light`
- `tokyonight`

## Theme Fields

Required UI colors:

- `THEME_MODE`: `dark` or `light`
- `THEME_COLOR_SCHEME`: optional palette family override. If omitted,
  `apply-theme.sh` infers it from the directory name.
- `THEME_VARIANT`: optional concrete variant override. If omitted,
  `apply-theme.sh` infers it from the directory name or `THEME_MODE`.

- `BG`
- `BG_ALT`
- `SURFACE`
- `SURFACE_HOVER`
- `FG`
- `FG_MUTED`
- `BORDER`
- `ACCENT`
- `ACCENT_2`
- `DANGER`
- `WARNING`
- `SUCCESS`

Required terminal colors:

- `BLACK`
- `RED`
- `GREEN`
- `YELLOW`
- `BLUE`
- `MAGENTA`
- `CYAN`
- `WHITE`
- `BRIGHT_BLACK`
- `BRIGHT_CYAN`
- `BRIGHT_WHITE`

## Add A Theme

Copy an existing theme:

```sh
cp -r themes/default themes/my-theme
```

Edit:

```text
themes/my-theme/theme.conf
```

Apply:

```sh
./apply-theme.sh my-theme
```
