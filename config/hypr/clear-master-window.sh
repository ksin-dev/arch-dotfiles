#!/bin/sh

workspace_id=$(hyprctl activeworkspace -j | jq -r '.id')

hyprctl clients -j |
  jq -r --argjson workspace_id "$workspace_id" \
    '.[] | select(.workspace.id == $workspace_id and (.tags // [] | index("hypr_manual_master"))) | .address' |
  while IFS= read -r address; do
    [ -n "$address" ] || continue
    hyprctl dispatch setprop "address:$address border_size 2"
    hyprctl dispatch setprop "address:$address active_border_color rgba(3b82f6ee)"
    hyprctl dispatch setprop "address:$address inactive_border_color rgba(334155aa)"
    hyprctl dispatch tagwindow "-hypr_manual_master address:$address"
  done
