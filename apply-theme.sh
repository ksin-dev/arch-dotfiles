#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
THEME_NAME=""
REQUESTED_COLOR_SCHEME=""
REQUESTED_MODE=""
LIST_THEMES=0

usage() {
  cat <<'EOF'
Usage:
  ./apply-theme.sh [theme-name]
  ./apply-theme.sh --color-scheme <scheme> [--mode dark|light]
  ./apply-theme.sh --colorScheme <scheme> [--mode dark|light]
  ./apply-theme.sh --mode dark|light
  ./apply-theme.sh --list

Examples:
  ./apply-theme.sh catppuccin-mocha
  ./apply-theme.sh --color-scheme catppuccin --mode light
  ./apply-theme.sh --mode dark
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --list | list)
      LIST_THEMES=1
      shift
      ;;
    --color-scheme | --colorScheme | --scheme)
      if [ "$#" -lt 2 ]; then
        printf '%s requires a value\n' "$1" >&2
        exit 1
      fi
      REQUESTED_COLOR_SCHEME="$2"
      shift 2
      ;;
    --mode)
      if [ "$#" -lt 2 ]; then
        printf '%s requires dark or light\n' "$1" >&2
        exit 1
      fi
      REQUESTED_MODE="$2"
      shift 2
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    -*)
      printf 'unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [ -n "$THEME_NAME" ]; then
        printf 'only one theme name can be provided\n' >&2
        exit 1
      fi
      THEME_NAME="$1"
      shift
      ;;
  esac
done

case "$REQUESTED_MODE" in
  "" | dark | light) ;;
  *)
    printf 'invalid mode: %s\n' "$REQUESTED_MODE" >&2
    printf 'mode must be dark or light\n' >&2
    exit 1
    ;;
esac

resolve_theme_metadata() {
  local theme_name="$1"

  THEME_MODE="${THEME_MODE:-dark}"
  case "$theme_name" in
    default-light)
      THEME_COLOR_SCHEME="${THEME_COLOR_SCHEME:-default}"
      THEME_VARIANT="${THEME_VARIANT:-light}"
      ;;
    catppuccin-*)
      THEME_COLOR_SCHEME="${THEME_COLOR_SCHEME:-catppuccin}"
      THEME_VARIANT="${THEME_VARIANT:-${theme_name#catppuccin-}}"
      ;;
    rose-pine-dawn)
      THEME_COLOR_SCHEME="${THEME_COLOR_SCHEME:-rose-pine}"
      THEME_VARIANT="${THEME_VARIANT:-dawn}"
      ;;
    rose-pine)
      THEME_COLOR_SCHEME="${THEME_COLOR_SCHEME:-rose-pine}"
      THEME_VARIANT="${THEME_VARIANT:-main}"
      ;;
    solarized-*)
      THEME_COLOR_SCHEME="${THEME_COLOR_SCHEME:-solarized}"
      THEME_VARIANT="${THEME_VARIANT:-${theme_name#solarized-}}"
      ;;
    *)
      THEME_COLOR_SCHEME="${THEME_COLOR_SCHEME:-$theme_name}"
      THEME_VARIANT="${THEME_VARIANT:-$THEME_MODE}"
      ;;
  esac
}

theme_metadata_line() {
  local theme="$1"

  (
    unset THEME_NAME THEME_COLOR_SCHEME THEME_VARIANT THEME_MODE
    # shellcheck disable=SC1090
    . "$DOTFILES_DIR/themes/$theme/theme.conf"
    resolve_theme_metadata "$theme"
    printf '%s\t%s\t%s\t%s\n' "$theme" "$THEME_COLOR_SCHEME" "$THEME_VARIANT" "$THEME_MODE"
  )
}

current_theme_name() {
  cat "$DOTFILES_DIR/config/hypr/theme/current" 2>/dev/null || true
}

current_theme_field() {
  local field="$1"
  local theme
  theme="$(current_theme_name)"

  if [ -n "$theme" ] && [ -f "$DOTFILES_DIR/themes/$theme/theme.conf" ]; then
    theme_metadata_line "$theme" | awk -F '\t' -v field="$field" '
      field == "name" { print $1 }
      field == "colorScheme" { print $2 }
      field == "variant" { print $3 }
      field == "mode" { print $4 }
    '
  fi
}

all_theme_metadata() {
  find "$DOTFILES_DIR/themes" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | while IFS= read -r theme; do
    theme_metadata_line "$theme"
  done
}

resolve_selected_theme() {
  if [ -n "$THEME_NAME" ] && [ -z "$REQUESTED_COLOR_SCHEME" ] && [ -z "$REQUESTED_MODE" ]; then
    printf '%s\n' "$THEME_NAME"
    return
  fi

  local target_scheme="$REQUESTED_COLOR_SCHEME"
  local target_mode="$REQUESTED_MODE"
  local mode_was_requested=1
  local theme scheme variant mode
  local metadata

  if [ -z "$target_scheme" ]; then
    if [ -n "$THEME_NAME" ] && [ -f "$DOTFILES_DIR/themes/$THEME_NAME/theme.conf" ]; then
      target_scheme="$(theme_metadata_line "$THEME_NAME" | awk -F '\t' '{ print $2 }')"
    else
      target_scheme="$(current_theme_field colorScheme)"
      target_scheme="${target_scheme:-default}"
    fi
  fi

  if [ -z "$target_mode" ]; then
    mode_was_requested=0
    target_mode="$(current_theme_field mode)"
    target_mode="${target_mode:-dark}"
  fi

  metadata="$(all_theme_metadata)"
  while IFS=$'\t' read -r theme scheme variant mode; do
    if { [ "$theme" = "$target_scheme" ] || [ "$scheme" = "$target_scheme" ]; } && [ "$mode" = "$target_mode" ]; then
      printf '%s\n' "$theme"
      return
    fi
  done <<< "$metadata"

  if [ "$mode_was_requested" -eq 0 ]; then
    while IFS=$'\t' read -r theme scheme variant mode; do
      if [ "$theme" = "$target_scheme" ] || [ "$scheme" = "$target_scheme" ]; then
        printf '%s\n' "$theme"
        return
      fi
    done <<< "$metadata"
  fi

  printf 'no theme matches colorScheme=%s mode=%s\n' "$target_scheme" "$target_mode" >&2
  printf 'available themes:\n' >&2
  "$0" --list >&2
  exit 1
}

if [ "$LIST_THEMES" -eq 1 ]; then
  current_file="$DOTFILES_DIR/config/hypr/theme/current"
  current_theme="$(cat "$current_file" 2>/dev/null || true)"
  printf '%-2s %-22s %-14s %-10s %-8s %s\n' "" "NAME" "COLOR_SCHEME" "VARIANT" "MODE" "STATUS"
  find "$DOTFILES_DIR/themes" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | while IFS= read -r theme; do
    IFS=$'\t' read -r theme_name color_scheme variant mode < <(theme_metadata_line "$theme")
    if [ "$theme" = "$current_theme" ]; then
      printf '*  %-22s %-14s %-10s %-8s active\n' "$theme_name" "$color_scheme" "$variant" "$mode"
    else
      printf '   %-22s %-14s %-10s %-8s\n' "$theme_name" "$color_scheme" "$variant" "$mode"
    fi
  done
  exit 0
fi

THEME_NAME="$(resolve_selected_theme)"
THEME_NAME="${THEME_NAME:-default}"
THEME_FILE="$DOTFILES_DIR/themes/$THEME_NAME/theme.conf"

if [ ! -f "$THEME_FILE" ]; then
  printf 'unknown theme: %s\n' "$THEME_NAME" >&2
  printf 'available themes:\n' >&2
  find "$DOTFILES_DIR/themes" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$THEME_FILE"

resolve_theme_metadata "$THEME_NAME"
ACCENT_FG="${ACCENT_FG:-#ffffff}"

strip_hash() {
  printf '%s' "${1#"#"}"
}

sync_generated_file() {
  local source_path="$1"
  local target_path="$2"
  local first_line=""

  mkdir -p "$(dirname "$target_path")"

  if [ "$(readlink -f "$source_path" 2>/dev/null || true)" = "$(readlink -f "$target_path" 2>/dev/null || true)" ]; then
    return
  fi

  if [ -L "$target_path" ]; then
    current_target="$(readlink "$target_path")"
    if [ "$current_target" = "$source_path" ]; then
      return
    fi
  fi

  if [ ! -e "$target_path" ]; then
    ln -s "$source_path" "$target_path"
    return
  fi

  first_line="$(sed -n '1p' "$target_path" 2>/dev/null || true)"
  case "$first_line" in
    *"Generated by apply-theme.sh"*)
      cp "$source_path" "$target_path"
      ;;
  esac
}

HYPR_THEME_DIR="$DOTFILES_DIR/config/hypr/theme"
QUICKSHELL_THEME_FILE="$DOTFILES_DIR/config/quickshell/Theme.js"
ALACRITTY_THEME_FILE="$HYPR_THEME_DIR/alacritty.toml"
HYPRLAND_THEME_FILE="$HYPR_THEME_DIR/hyprland.conf"
KITTY_THEME_FILE="$DOTFILES_DIR/config/kitty/theme.conf"
CHROME_FLAGS_FILE="$DOTFILES_DIR/config/chrome-flags.conf"
GTK3_DIR="$DOTFILES_DIR/config/gtk-3.0"
GTK4_DIR="$DOTFILES_DIR/config/gtk-4.0"
mkdir -p "$HYPR_THEME_DIR"
mkdir -p "$DOTFILES_DIR/config/quickshell"
mkdir -p "$DOTFILES_DIR/config/kitty"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"

case "$THEME_MODE" in
  light)
    GTK_PREFER_DARK=0
    GNOME_COLOR_SCHEME="prefer-light"
    CHROME_DARK_FLAGS=""
    CHROME_FEATURES="TouchpadOverscrollHistoryNavigation"
    ;;
  dark | *)
    GTK_PREFER_DARK=1
    GNOME_COLOR_SCHEME="prefer-dark"
    CHROME_DARK_FLAGS="--force-dark-mode"
    CHROME_FEATURES="TouchpadOverscrollHistoryNavigation,WebUIDarkMode"
    ;;
esac

cat > "$QUICKSHELL_THEME_FILE" <<EOF
.pragma library

var name = "$THEME_NAME"
var colorScheme = "$THEME_COLOR_SCHEME"
var variant = "$THEME_VARIANT"
var mode = "$THEME_MODE"
var bg = "$BG"
var bgAlt = "$BG_ALT"
var surface = "$SURFACE"
var surfaceHover = "$SURFACE_HOVER"
var fg = "$FG"
var fgMuted = "$FG_MUTED"
var border = "$BORDER"
var accent = "$ACCENT"
var accent2 = "$ACCENT_2"
var accentFg = "$ACCENT_FG"
var danger = "$DANGER"
var warning = "$WARNING"
var success = "$SUCCESS"
EOF

cat > "$ALACRITTY_THEME_FILE" <<EOF
[colors.primary]
background = "$BG"
foreground = "$FG"

[colors.normal]
black = "$BLACK"
red = "$RED"
green = "$GREEN"
yellow = "$YELLOW"
blue = "$BLUE"
magenta = "$MAGENTA"
cyan = "$CYAN"
white = "$WHITE"

[colors.bright]
black = "$BRIGHT_BLACK"
red = "$RED"
green = "$GREEN"
yellow = "$YELLOW"
blue = "$BLUE"
magenta = "$MAGENTA"
cyan = "$BRIGHT_CYAN"
white = "$BRIGHT_WHITE"
EOF

cat > "$KITTY_THEME_FILE" <<EOF
# Generated by apply-theme.sh. Do not edit by hand.
foreground $FG
background $BG
selection_foreground $BG
selection_background $ACCENT
cursor $FG
cursor_text_color $BG
url_color $ACCENT_2
active_border_color $ACCENT
inactive_border_color $BORDER
bell_border_color $WARNING

color0 $BLACK
color1 $RED
color2 $GREEN
color3 $YELLOW
color4 $BLUE
color5 $MAGENTA
color6 $CYAN
color7 $WHITE
color8 $BRIGHT_BLACK
color9 $RED
color10 $GREEN
color11 $YELLOW
color12 $BLUE
color13 $MAGENTA
color14 $BRIGHT_CYAN
color15 $BRIGHT_WHITE
EOF

cat > "$CHROME_FLAGS_FILE" <<EOF
# Generated by apply-theme.sh. Do not edit by hand.
--ozone-platform=wayland
--ozone-platform-hint=wayland
--enable-features=$CHROME_FEATURES
# Chromium crash workaround for Wayland color management on Hyprland.
--disable-features=WaylandWpColorManagerV1
$CHROME_DARK_FLAGS
EOF

accent="$(strip_hash "$ACCENT")"
accent2="$(strip_hash "$ACCENT_2")"
border="$(strip_hash "$BORDER")"
shadow="$(strip_hash "$BG")"

cat > "$HYPRLAND_THEME_FILE" <<EOF
# Generated by apply-theme.sh. Do not edit by hand.
general {
    col.active_border = rgba(${accent}ee) rgba(${accent2}ee) 45deg
    col.inactive_border = rgba(${border}aa)
}

decoration {
    shadow {
        color = rgba(${shadow}ee)
    }
}
EOF

write_gtk_settings() {
  target_dir="$1"

  cat > "$target_dir/settings.ini" <<EOF
# Generated by apply-theme.sh. Do not edit by hand.
[Settings]
gtk-application-prefer-dark-theme=$GTK_PREFER_DARK
gtk-theme-name=Adwaita
gtk-icon-theme-name=Adwaita
EOF

  cat > "$target_dir/gtk.css" <<EOF
/* Generated by apply-theme.sh. Do not edit by hand. */
@define-color accent_color $ACCENT;
@define-color accent_bg_color $ACCENT;
@define-color accent_fg_color $FG;
@define-color destructive_color $DANGER;
@define-color destructive_bg_color $DANGER;
@define-color success_color $SUCCESS;
@define-color success_bg_color $SUCCESS;
@define-color warning_color $WARNING;
@define-color warning_bg_color $WARNING;
@define-color error_color $DANGER;
@define-color error_bg_color $DANGER;
@define-color window_bg_color $BG_ALT;
@define-color window_fg_color $FG;
@define-color view_bg_color $BG;
@define-color view_fg_color $FG;
@define-color headerbar_bg_color $BG_ALT;
@define-color headerbar_fg_color $FG;
@define-color card_bg_color $SURFACE;
@define-color card_fg_color $FG;
@define-color popover_bg_color $BG_ALT;
@define-color popover_fg_color $FG;
@define-color dialog_bg_color $BG_ALT;
@define-color dialog_fg_color $FG;
EOF
}

write_gtk_settings "$GTK3_DIR"
write_gtk_settings "$GTK4_DIR"

sync_generated_file "$DOTFILES_DIR/config/kitty/theme.conf" "$HOME/.config/kitty/theme.conf"
sync_generated_file "$DOTFILES_DIR/config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
sync_generated_file "$DOTFILES_DIR/config/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
sync_generated_file "$DOTFILES_DIR/config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
sync_generated_file "$DOTFILES_DIR/config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
sync_generated_file "$CHROME_FLAGS_FILE" "$HOME/.config/chrome-flags.conf"

if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface color-scheme "$GNOME_COLOR_SCHEME" >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.interface gtk-theme "Adwaita" >/dev/null 2>&1 || true
fi

if command -v kitty >/dev/null 2>&1 && pgrep -u "${USER:-$(id -un)}" -x kitty >/dev/null 2>&1; then
  kitty @ load-config >/dev/null 2>&1 || true
fi

if [ -d "$HOME/.local/share/applications" ] && command -v sed >/dev/null 2>&1; then
  find "$HOME/.local/share/applications" -maxdepth 1 -type f -name 'chrome-*.desktop' -exec \
    sed -i 's#Exec=/opt/google/chrome/google-chrome #Exec=/usr/bin/google-chrome-stable #g' {} +
fi

printf '%s\n' "$THEME_NAME" > "$HYPR_THEME_DIR/current"

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi

user_name="${USER:-$(id -un)}"
quickshell_running() {
  pgrep -u "$user_name" -x quickshell >/dev/null 2>&1 ||
    pgrep -u "$user_name" -f "qs -p $HOME/.config/quickshell" >/dev/null 2>&1
}

run_qs_kill() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 2 qs kill -p "$HOME/.config/quickshell" >/dev/null 2>&1 || timeout 2 qs kill >/dev/null 2>&1 || true
  else
    qs kill -p "$HOME/.config/quickshell" >/dev/null 2>&1 || qs kill >/dev/null 2>&1 || true
  fi
}

stop_quickshell() {
  run_qs_kill
  i=0
  while quickshell_running && [ "$i" -lt 20 ]; do
    sleep 0.1
    i=$((i + 1))
  done
  if quickshell_running; then
    pkill -TERM -u "$user_name" -x quickshell >/dev/null 2>&1 || true
    pkill -TERM -u "$user_name" -f "qs -p $HOME/.config/quickshell" >/dev/null 2>&1 || true
  fi
  i=0
  while quickshell_running && [ "$i" -lt 20 ]; do
    sleep 0.1
    i=$((i + 1))
  done
}

qs_was_running=0
if command -v qs >/dev/null 2>&1 && quickshell_running; then
  qs_was_running=1
fi

if [ "$qs_was_running" -eq 1 ]; then
  stop_quickshell
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch exec "qs -p $HOME/.config/quickshell --no-duplicate --log-times" >/dev/null 2>&1 || true
  fi
  sleep 0.5
  if ! quickshell_running; then
    setsid qs -p "$HOME/.config/quickshell" --no-duplicate --log-times >/tmp/quickshell-theme.log 2>&1 &
  fi
fi

printf 'applied theme: %s\n' "$THEME_NAME"
