# Yazi

Terminal file manager configuration.

## Required

- `yazi`

## Optional

- `nvim`: default text opener
- `ffmpegthumbnailer`, `poppler`, `fd`, `ripgrep`, `fzf`: useful preview/search helpers depending on your Yazi setup

## Files

- `yazi.toml`: main manager/open/preview settings
- `keymap.toml`: key bindings
- `theme.toml`: terminal-theme-friendly colors

## Keybind Help

The Quickshell keybind help overlay reads `keymap.toml`.

Use `# @group ...` before related entries and `desc = "..."` inside keymap
items. The overlay uses those values to render the Yazi sidebar section.

Yazi 26.5.x uses the `[mgr]` layer for the main file list in `yazi.toml`,
`keymap.toml`, and `theme.toml`. In the default Yazi keymap, `F1` and `~` open
help, `/` starts a forward find, and `?` starts a previous/backward find.

## Install

```sh
./install.sh yazi
```
