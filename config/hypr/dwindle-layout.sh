#!/bin/sh

workspace_id=$(hyprctl activeworkspace -j | jq -r '.id')
state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-window-layouts"
mkdir -p "$state_dir"
printf '%s\n' "dwindle" > "$state_dir/workspace-$workspace_id"

~/.config/hypr/clear-master-window.sh
hyprctl keyword general:layout dwindle
