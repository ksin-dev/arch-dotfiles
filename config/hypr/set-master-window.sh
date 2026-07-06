#!/bin/sh

tag_name="hypr_manual_master"
workspace_id=$(hyprctl activeworkspace -j | jq -r '.id')
active_address=$(hyprctl activewindow -j | jq -r '.address')

hyprctl clients -j |
  jq -r --argjson workspace_id "$workspace_id" \
    '.[] | select(.workspace.id == $workspace_id and (.tags // [] | index("hypr_manual_master"))) | .address' |
  while IFS= read -r address; do
    [ -n "$address" ] || continue
    hyprctl dispatch setprop "address:$address border_size 2"
    hyprctl dispatch setprop "address:$address active_border_color rgba(3b82f6ee)"
    hyprctl dispatch setprop "address:$address inactive_border_color rgba(334155aa)"
    hyprctl dispatch tagwindow "-$tag_name address:$address"
  done

hyprctl dispatch tagwindow "+$tag_name address:$active_address"
hyprctl dispatch layoutmsg "swapwithmaster master ignoremaster"
hyprctl dispatch setprop "address:$active_address border_size 4"
hyprctl dispatch setprop "address:$active_address active_border_color rgb(88c0d0)"
hyprctl dispatch setprop "address:$active_address inactive_border_color rgb(5e81ac)"
hyprctl notify 1 1800 "rgb(ffcc00)" "Master window set"
