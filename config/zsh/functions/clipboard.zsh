# Copy stdin or a string to the local terminal's clipboard over OSC 52.
# This is useful from a remote SSH host, where wl-copy targets the remote
# session rather than the local desktop clipboard.
osc52copy() {
  local payload

  if (( $# )); then
    payload=$(printf '%s' "$*" | base64 | tr -d '\n') || return
  else
    payload=$(base64 | tr -d '\n') || return
  fi

  printf '\033]52;c;%s\033\\' "$payload"
}
