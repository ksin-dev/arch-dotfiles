#!/bin/sh
set -eu

DOTFILES_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG_DIR="$DOTFILES_DIR/config"
BACKUP_DIR="$DOTFILES_DIR/backup-$(date +%Y%m%d-%H%M%S)"

CONFIGS="
hypr
nvim
alacritty
kitty
starship
waybar
gtk-3.0
gtk-4.0
yazi
zsh
chrome
quickshell
herdr
"

mkdir -p "$HOME/.config"

install_arch_packages() {
  label="$1"
  shift

  if [ "${DOTFILES_SKIP_PACKAGES:-0}" = "1" ]; then
    printf 'skip: package install disabled for %s\n' "$label"
    return
  fi

  if ! command -v pacman >/dev/null 2>&1; then
    printf 'skip: pacman not found; install %s packages manually: %s\n' "$label" "$*" >&2
    return
  fi

  pacman_targets=""
  aur_targets=""

  for package in "$@"; do
    if pacman -Q "$package" >/dev/null 2>&1; then
      continue
    fi

    if pacman -Si "$package" >/dev/null 2>&1; then
      pacman_targets="$pacman_targets $package"
    else
      aur_targets="$aur_targets $package"
    fi
  done

  if [ -n "$pacman_targets" ]; then
    printf 'install: %s pacman packages:%s\n' "$label" "$pacman_targets"
    sudo pacman -S --needed $pacman_targets
  fi

  if [ -n "$aur_targets" ]; then
    if command -v paru >/dev/null 2>&1; then
      printf 'install: %s AUR packages:%s\n' "$label" "$aur_targets"
      paru -S --needed $aur_targets
    elif command -v yay >/dev/null 2>&1; then
      printf 'install: %s AUR packages:%s\n' "$label" "$aur_targets"
      yay -S --needed $aur_targets
    else
      printf 'warn: install these %s AUR packages manually:%s\n' "$label" "$aur_targets" >&2
    fi
  fi
}

install_quickshell_package() {
  if command -v qs >/dev/null 2>&1 || command -v quickshell >/dev/null 2>&1; then
    return
  fi

  install_arch_packages "quickshell" quickshell-git
}

enable_bluetooth_service() {
  if [ "${DOTFILES_SKIP_PACKAGES:-0}" = "1" ]; then
    return
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    printf 'skip: systemctl not found; enable bluetooth.service manually\n' >&2
    return
  fi

  if ! systemctl is-enabled --quiet bluetooth.service 2>/dev/null; then
    printf 'enable: bluetooth.service\n'
    sudo systemctl enable bluetooth.service
  fi

  if ! systemctl is-active --quiet bluetooth.service; then
    printf 'start: bluetooth.service\n'
    sudo systemctl start bluetooth.service
  fi
}

install_selected_packages() {
  if is_selected "hypr"; then
    install_arch_packages "hypr" \
      hyprland \
      hyprpaper \
      hypridle \
      hyprlock \
      bluez \
      blueman \
      fcitx5 \
      fcitx5-hangul \
      kitty \
      yazi \
      nautilus \
      jq \
      nwg-displays \
      grim \
      slurp \
      swappy
    enable_bluetooth_service
    install_quickshell_package
  fi

  if is_selected "quickshell"; then
    install_quickshell_package
  fi
}

print_menu() {
  printf 'Select configs to install:\n'
  index=1
  for name in $CONFIGS; do
    printf '  %s) %s\n' "$index" "$name"
    index=$((index + 1))
  done
  printf '\n'
  printf 'Enter numbers or names separated by spaces. Examples: 1 3 zsh, all\n'
}

resolve_selection() {
  selection=""

  if [ "$#" -gt 0 ]; then
    input="$*"
  else
    print_menu
    printf '> '
    read -r input
  fi

  if [ -z "$input" ]; then
    printf 'No selection. Nothing installed.\n'
    exit 0
  fi

  for item in $input; do
    case "$item" in
      all | '*')
        selection="$CONFIGS"
        ;;
      1) selection="$selection hypr" ;;
      2) selection="$selection nvim" ;;
      3) selection="$selection alacritty" ;;
      4) selection="$selection kitty" ;;
      5) selection="$selection starship" ;;
      6) selection="$selection waybar" ;;
      7) selection="$selection gtk-3.0" ;;
      8) selection="$selection gtk-4.0" ;;
      9) selection="$selection yazi" ;;
      10) selection="$selection zsh" ;;
      11) selection="$selection chrome" ;;
      12) selection="$selection quickshell" ;;
      13) selection="$selection herdr" ;;
      hypr | nvim | alacritty | kitty | starship | waybar | gtk-3.0 | gtk-4.0 | yazi | zsh | chrome | quickshell | herdr)
        selection="$selection $item"
        ;;
      *)
        printf 'unknown selection: %s\n' "$item" >&2
        exit 1
        ;;
    esac
  done
}

is_selected() {
  needle="$1"

  for name in $selection; do
    if [ "$name" = "$needle" ]; then
      return 0
    fi
  done

  return 1
}

install_config() {
  name="$1"
  source_dir="$CONFIG_DIR/$name"
  target_dir="$HOME/.config/$name"

  if [ ! -d "$source_dir" ]; then
    printf 'skip: config/%s does not exist\n' "$name"
    return
  fi

  if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target_dir" "$BACKUP_DIR/$name"
    printf 'backup: %s -> %s/%s\n' "$target_dir" "$BACKUP_DIR" "$name"
  fi

  cp -a "$source_dir" "$target_dir"
  printf 'installed: %s -> %s\n' "$source_dir" "$target_dir"
}

link_config() {
  name="$1"
  source_dir="$CONFIG_DIR/$name"
  target_dir="$HOME/.config/$name"

  if [ ! -d "$source_dir" ]; then
    printf 'skip: config/%s does not exist\n' "$name"
    return
  fi

  if [ -L "$target_dir" ] && [ "$(readlink "$target_dir")" = "$source_dir" ]; then
    printf 'ok: %s already links to %s\n' "$target_dir" "$source_dir"
    return
  fi

  if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target_dir" "$BACKUP_DIR/$name"
    printf 'backup: %s -> %s/%s\n' "$target_dir" "$BACKUP_DIR" "$name"
  fi

  ln -s "$source_dir" "$target_dir"
  printf 'linked: %s -> %s\n' "$target_dir" "$source_dir"
}

install_config_file() {
  name="$1"
  source_path="$CONFIG_DIR/$name"
  target_path="$HOME/.config/$name"

  if [ ! -f "$source_path" ]; then
    printf 'skip: config/%s does not exist\n' "$name"
    return
  fi

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target_path" "$BACKUP_DIR/$name"
    printf 'backup: %s -> %s/%s\n' "$target_path" "$BACKUP_DIR" "$name"
  fi

  cp -a "$source_path" "$target_path"
  printf 'installed: %s -> %s\n' "$source_path" "$target_path"
}

install_config_subfile() {
  source_rel="$1"
  target_rel="$2"
  source_path="$CONFIG_DIR/$source_rel"
  target_path="$HOME/.config/$target_rel"
  target_parent=$(dirname "$target_path")

  if [ ! -f "$source_path" ]; then
    printf 'skip: config/%s does not exist\n' "$source_rel"
    return
  fi

  mkdir -p "$target_parent"

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    backup_path="$BACKUP_DIR/$target_rel"
    mkdir -p "$(dirname "$backup_path")"
    mv "$target_path" "$backup_path"
    printf 'backup: %s -> %s\n' "$target_path" "$backup_path"
  fi

  cp -a "$source_path" "$target_path"
  printf 'installed: %s -> %s\n' "$source_path" "$target_path"
}

link_config_subfile() {
  source_rel="$1"
  target_rel="$2"
  source_path="$CONFIG_DIR/$source_rel"
  target_path="$HOME/.config/$target_rel"
  target_parent=$(dirname "$target_path")

  if [ ! -f "$source_path" ]; then
    printf 'skip: config/%s does not exist\n' "$source_rel"
    return
  fi

  mkdir -p "$target_parent"

  if [ -L "$target_path" ] && [ "$(readlink "$target_path")" = "$source_path" ]; then
    printf 'ok: %s already links to %s\n' "$target_path" "$source_path"
    return
  fi

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    backup_path="$BACKUP_DIR/$target_rel"
    mkdir -p "$(dirname "$backup_path")"
    mv "$target_path" "$backup_path"
    printf 'backup: %s -> %s\n' "$target_path" "$backup_path"
  fi

  ln -s "$source_path" "$target_path"
  printf 'linked: %s -> %s\n' "$target_path" "$source_path"
}

resolve_selection "$@"
install_selected_packages

for name in $CONFIGS; do
  if is_selected "$name"; then
    case "$name" in
      hypr | nvim | quickshell)
        link_config "$name"
        ;;
      gtk-3.0 | gtk-4.0)
        install_config_subfile "$name/settings.ini" "$name/settings.ini"
        install_config_subfile "$name/gtk.css" "$name/gtk.css"
        ;;
      chrome)
        install_config_file "chrome-flags.conf"
        ;;
      herdr)
        link_config_subfile "herdr/config.toml" "herdr/config.toml"
        ;;
      *)
        install_config "$name"
        ;;
    esac
  fi
done

install_home_path() {
  name="$1"
  source_path="$DOTFILES_DIR/home/$name"
  target_path="$HOME/$name"

  if [ ! -e "$source_path" ]; then
    printf 'skip: home/%s does not exist\n' "$name"
    return
  fi

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target_path" "$BACKUP_DIR/$name"
    printf 'backup: %s -> %s/%s\n' "$target_path" "$BACKUP_DIR" "$name"
  fi

  cp -a "$source_path" "$target_path"
  printf 'installed: %s -> %s\n' "$source_path" "$target_path"
}

install_bin_path() {
  name="$1"
  source_path="$DOTFILES_DIR/bin/$name"
  target_path="$HOME/.local/bin/$name"

  if [ ! -e "$source_path" ]; then
    printf 'skip: bin/%s does not exist\n' "$name"
    return
  fi

  mkdir -p "$HOME/.local/bin"

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target_path" "$BACKUP_DIR/$name"
    printf 'backup: %s -> %s/%s\n' "$target_path" "$BACKUP_DIR" "$name"
  fi

  cp -a "$source_path" "$target_path"
  chmod +x "$target_path"
  printf 'installed: %s -> %s\n' "$source_path" "$target_path"
}

ensure_user_config_file() {
  source_path="$1"
  target_path="$2"

  if [ ! -f "$source_path" ]; then
    printf 'skip: %s does not exist\n' "$source_path"
    return
  fi

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    printf 'ok: %s already exists\n' "$target_path"
    return
  fi

  mkdir -p "$(dirname "$target_path")"
  cp "$source_path" "$target_path"
  printf 'created: %s from %s\n' "$target_path" "$source_path"
}

if is_selected "hypr" || is_selected "quickshell"; then
  install_bin_path "qs-toggle-launcher"
  install_bin_path "qs-toggle-keybinds"
  install_bin_path "qs-notifications"
  install_bin_path "qs-shell"
  install_bin_path "hypr-btop"
  install_bin_path "hypr-monitor-cycle"
  install_bin_path "hypr-idle-settings"
  install_bin_path "qs-idle-inhibit"
  install_bin_path "qs-monitor-settings"
fi

if is_selected "hypr"; then
  mkdir -p "$HOME/Pictures/Screenshots"
  ensure_user_config_file "$CONFIG_DIR/swappy/config" "$HOME/.config/swappy/config"
  ensure_user_config_file "$CONFIG_DIR/dotfiles/hypr/monitors.conf.example" "$HOME/.config/dotfiles/hypr/monitors.conf"
  ensure_user_config_file "$CONFIG_DIR/dotfiles/hypr/workspaces.conf.example" "$HOME/.config/dotfiles/hypr/workspaces.conf"
  ensure_user_config_file "$CONFIG_DIR/dotfiles/hypr/idle.json.example" "$HOME/.config/dotfiles/hypr/idle.json"
fi

if is_selected "quickshell"; then
  ensure_user_config_file "$CONFIG_DIR/dotfiles/quickshell.json.example" "$HOME/.config/dotfiles/quickshell.json"
fi

if is_selected "zsh"; then
  install_home_path ".zshenv"
  install_home_path ".p10k.zsh"
fi
