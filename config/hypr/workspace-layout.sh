#!/bin/sh

target="$1"
[ -n "$target" ] || exit 1

hyprctl dispatch workspace "$target"
