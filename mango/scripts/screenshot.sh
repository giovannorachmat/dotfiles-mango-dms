#!/usr/bin/env bash
# ponytail: one script for all 4 modes; satty does annotate/save/copy itself
dir="$HOME/Pictures/Screenshots"
out="$dir/screenshot_%Y-%m-%d_%H-%M-%S.png"
mkdir -p "$dir"

case "$1" in
region)
  sel=$(slurp) || exit 1
  [ -n "$sel" ] || exit 1
  set -- grim -g "$sel" -
  ;;
*)
  mon=$(mmsg get all-monitors | jq -r '.monitors[] | select(.active).name')
  [ -n "$mon" ] && [ "$mon" != null ] || exit 1
  set -- grim -o "$mon" -
  ;;
esac

case "$2" in
clipboard) "$@" | satty -f - --floating-hack --copy-command wl-copy --actions-on-enter save-to-clipboard --early-exit copy ;;
*) "$@" | satty -f - --floating-hack -o "$out" --actions-on-enter save-to-file --early-exit save ;;
esac
