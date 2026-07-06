#!/bin/sh

fcitx_keymap=""

if command -v fcitx5-remote >/dev/null 2>&1; then
    fcitx_name=$(fcitx5-remote -n 2>/dev/null || true)
    fcitx_state=$(fcitx5-remote 2>/dev/null || true)
    fcitx_normalized=$(printf '%s' "$fcitx_name" | tr '[:upper:]' '[:lower:]')

    case "$fcitx_normalized:$fcitx_state" in
        *hangul*|*korean*|*:2)
            fcitx_keymap="Korean"
            ;;
        *english*|*keyboard-us*|*keyboard_us*|*:1|*:0)
            fcitx_keymap="English (US)"
            ;;
    esac
fi

hypr=$(
    hyprctl -j devices 2>/dev/null \
        | jq -r '([.keyboards[] | select((.name | contains("virtual")) | not)][0] // [.keyboards[] | select(.main == true)][0] // .keyboards[0]) | [(.active_keymap // "Unknown"), (.layout // ""), (.active_layout_index // -1), (.capsLock // false), (.numLock // false)] | @tsv' 2>/dev/null \
        | tr '\t' '|'
)

IFS='|' read -r hypr_keymap layout layout_index caps_lock num_lock <<EOF
$hypr
EOF

keymap=${fcitx_keymap:-${hypr_keymap:-Unknown}}
layout=${layout:-}
layout_index=${layout_index:--1}
caps_lock=${caps_lock:-false}
num_lock=${num_lock:-false}

printf '%s|%s|%s|%s|%s' "$keymap" "$layout" "$layout_index" "$caps_lock" "$num_lock"
