#!/bin/sh

orientation="${1:-left}"
mode="${2:-single}"

workspace_id=$(hyprctl activeworkspace -j | jq -r '.id')
state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-window-layouts"
mkdir -p "$state_dir"
printf '%s %s\n' "$orientation" "$mode" > "$state_dir/workspace-$workspace_id"

window_count=$(
  hyprctl clients -j |
    jq --argjson workspace_id "$workspace_id" \
      '[.[] | select(.workspace.id == $workspace_id and .floating == false)] | length'
)

hyprctl keyword general:layout master
hyprctl dispatch layoutmsg "orientation$orientation"

# Keep normal master layouts predictable after using the all-master layout.
i=0
while [ "$i" -lt 30 ]; do
  hyprctl dispatch layoutmsg removemaster
  i=$((i + 1))
done

[ "$mode" = "all" ] || exit 0

~/.config/hypr/clear-master-window.sh

i=1
while [ "$i" -lt "$window_count" ]; do
  hyprctl dispatch layoutmsg addmaster
  i=$((i + 1))
done
