#!/usr/bin/env bash
# Toggle gpu-screen-recorder (macOS-style: press to start, press again to stop).
#
# Usage:
#   screen-record monitor - record the active monitor (the one with the pointer)
#   screen-record region  - drag-select a region with slurp, then record it
#
# Output: ~/Videos/recording/<YYYY-MM-DD>_<HHMMSS>_record.mp4
# mp4 + H.264 (gpu-screen-recorder default) plays in essentially every
# player/browser/editor (VLC, mpv, Windows, macOS, browsers, Kdenlive).

set -euo pipefail

RECORD_DIR="$HOME/Videos/recording"

ACTION=${1:-monitor}
case "$ACTION" in
monitor | region) ;;
*)
  printf 'Usage: %s {monitor|region}\n' "$0" >&2
  exit 1
  ;;
esac

if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
  printf 'mango-record: not in a wayland session\n' >&2
  exit 1
fi
if ! command -v gpu-screen-recorder >/dev/null 2>&1; then
  printf 'mango-record: gpu-screen-recorder is not installed\n' >&2
  exit 127
fi

notify() {
  command -v notify-send >/dev/null 2>&1 &&
    notify-send -a mango-record "$1" "$2" >/dev/null 2>&1 || true
}

# gpu-screen-recorder stops and finalizes the file on SIGINT.
# -x is useless here (process name exceeds the 15-char comm limit), anchor on argv.
if pgrep -f '^gpu-screen-recorder' >/dev/null; then
  pkill -SIGINT -f '^gpu-screen-recorder'
  notify 'Recording stopping' 'finalizing the mp4 file'
  exit 0
fi

if [[ $ACTION == region ]]; then
  # -f keeps slurp's old X,Y WxH default out of the picture: output WxH+X+Y,
  # fed straight to -w (modern form of -region); non-zero exit = Escape-cancel.
  # -b is BACKGROUND color (not weight!): bad colors silently fall back to
  # opaque white, hence the explicit 20%-alpha bg, red border, 4px border (-w).
  target=$(slurp -f '%wx%h+%x+%y' -w 4 -c '#ff2626' -b '#ffffff33') || exit 0
else
  # Record the monitor holding the pointer, same detection as screenshot.sh.
  target=$(mmsg get cursorpos | jq -r '.monitor // empty')
  [[ -n $target ]] || exit 1
fi

mkdir -p "$RECORD_DIR"
output="$RECORD_DIR/$(date +%Y-%m-%d_%H%M%S)_record.mp4"

nohup gpu-screen-recorder -w "$target" \
  -f 60 -encoder gpu -exclude-metadata yes -tune quality \
  -c mp4 -o "$output" >/dev/null 2>&1 &
notify "Recording" "$output - press again to stop"
