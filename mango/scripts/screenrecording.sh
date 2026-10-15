#!/usr/bin/env bash
# Toggle gpu-screen-recorder (macOS-style: press to start, press again to stop).
#
# Usage:
#   screen-record monitor - record the active monitor (the one with the pointer)
#   screen-record region  - drag-select a region with slop, then record it
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

region_args=()
if [[ $ACTION == region ]]; then
  # slurp's default output is exactly the WxH+X+Y geometry that
  # gpu-screen-recorder's -region wants; non-zero exit means Escape-cancel.
  target=region
  geom=$(slurp -b 4 -c 1,0.15,0.15,1) || exit 0 # red-ish frame; slurp's default is barely visible
  region_args=(-region "$geom")
else
  # Record the monitor holding the pointer, same detection as screenshot.sh.
  target=$(mmsg get cursorpos | jq -r '.monitor // empty')
  [[ -n $target ]] || exit 1
fi

mkdir -p "$RECORD_DIR"
output="$RECORD_DIR/$(date +%Y-%m-%d_%H%M%S)_record.mp4"

nohup gpu-screen-recorder -w "$target" ${region_args[@]+"${region_args[@]}"} \
  -c mp4 -o "$output" >/dev/null 2>&1 &
notify "Recording" "$output - press again to stop"
