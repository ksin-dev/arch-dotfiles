# Zsh

Zsh configuration with Oh My Zsh plugins and Powerlevel10k.

## Files

- `.zshrc`: main shell startup file
- `ohmyzsh/`: local Oh My Zsh tree and plugins
- `completions/`: local completions
- `functions/`: local helper functions
- `plugin.zsh`, `prompt.zsh`, `user.zsh`: additional shell config files
- `zsh.local.zsh.example`: template for machine-specific SDK paths
- `../../home/.zshenv`: sets `ZDOTDIR`
- `../../home/.p10k.zsh`: Powerlevel10k prompt settings

## Required

- `zsh`
- `git`
- A Nerd Font compatible with Powerlevel10k
- Powerlevel10k installed at `~/powerlevel10k`

## Prompt

The home `.zshenv` sets:

```sh
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
```

The prompt is loaded from:

```sh
~/powerlevel10k/powerlevel10k.zsh-theme
~/.p10k.zsh
```

Install Powerlevel10k separately:

```sh
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
```

## Plugins

Configured in `.zshrc`:

```sh
plugins=(git fzf fzf-tab zsh-autosuggestions zsh-syntax-highlighting)
```

The plugin sources are included under `ohmyzsh/plugins`.

## Optional Tools Used By Startup Scripts

- `fzf`
- `fastfetch`
- `pokego`
- `pokemon-colorscripts`

## Local Environment

Programming-language SDK paths and machine-specific tools are intentionally not
tracked in the shared zsh config. The shared `.zshrc` loads this file when it
exists:

```sh
~/.config/zsh.local.zsh
```

Create it from the template:

```sh
cp ~/.config/zsh/zsh.local.zsh.example ~/.config/zsh.local.zsh
```

Use that local file for paths such as:

- `asdf`
- Flutter SDK
- Android Studio
- Android SDK
- Java
- Chrome executable

The installer does not create, replace, or delete `~/.config/zsh.local.zsh`.

## Install

From the repository root:

```sh
./install.sh zsh
```

This installs:

- `~/.config/zsh`
- `~/.zshenv`
- `~/.p10k.zsh`

It does not install Powerlevel10k itself. Install that external dependency
separately with the command above.
