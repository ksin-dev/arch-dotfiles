#!/bin/sh
set -eu

DOTFILES_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG_DIR="$DOTFILES_DIR/config"

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
herdr
"

mkdir -p "$CONFIG_DIR"
mkdir -p "$DOTFILES_DIR/home"

copy_config() {
  name="$1"
  source_dir="$HOME/.config/$name"
  target_dir="$CONFIG_DIR/$name"

  if [ ! -d "$source_dir" ]; then
    printf 'skip: %s does not exist\n' "$source_dir"
    return
  fi

  rm -rf "$target_dir"
  mkdir -p "$target_dir"

  tar \
    --exclude=.git \
    --exclude=.zsh_history \
    --exclude='.zcompdump*' \
    --exclude='*.zwc' \
    -C "$source_dir" -cf - . | tar -C "$target_dir" -xf -
  printf 'updated: config/%s\n' "$name"
}

copy_config_file() {
  name="$1"
  source_path="$HOME/.config/$name"
  target_path="$CONFIG_DIR/$name"

  if [ ! -f "$source_path" ]; then
    printf 'skip: %s does not exist\n' "$source_path"
    return
  fi

  mkdir -p "$(dirname "$target_path")"
  cp "$source_path" "$target_path"
  printf 'updated: config/%s\n' "$name"
}

for name in $CONFIGS; do
  case "$name" in
    herdr)
      copy_config_file "herdr/config.toml"
      ;;
    *)
      copy_config "$name"
      ;;
  esac
done

copy_home_path() {
  name="$1"
  source_path="$HOME/$name"
  target_path="$DOTFILES_DIR/home/$name"

  if [ ! -e "$source_path" ]; then
    printf 'skip: %s does not exist\n' "$source_path"
    return
  fi

  rm -rf "$target_path"

  if [ -d "$source_path" ]; then
    mkdir -p "$target_path"
    tar --exclude=.git --exclude='*.zwc' -C "$source_path" -cf - . | tar -C "$target_path" -xf -
  else
    cp "$source_path" "$target_path"
  fi

  printf 'updated: home/%s\n' "$name"
}

copy_home_path ".zshenv"
copy_home_path ".p10k.zsh"
