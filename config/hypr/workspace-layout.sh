#!/bin/sh

target="$1"
[ -n "$target" ] || exit 1

hyprctl dispatch workspace "$target"
sleep 0.05

workspace_id=$(hyprctl activeworkspace -j | jq -r '.id')
state_file="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-window-layouts/workspace-$workspace_id"

if [ ! -f "$state_file" ]; then
  ~/.config/hypr/dwindle-layout.sh
  exit 0
fi

set -- $(cat "$state_file")

case "$1" in
  dwindle)
    ~/.config/hypr/dwindle-layout.sh
    ;;
  top|left|right|bottom)
    ~/.config/hypr/master-layout.sh "$1" "${2:-single}"
    ;;
  *)
    ~/.config/hypr/dwindle-layout.sh
    ;;
esac
