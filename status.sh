#!/bin/bash
# Report the active gpu-screen-recorder region as JSON.
# Omarchy stores region geometry on -w as WxH+X+Y (logical compositor space).

pid=$(pgrep -n -f '^gpu-screen-recorder' 2>/dev/null || true)
if [[ -z ${pid:-} || ! -r /proc/$pid/cmdline ]]; then
  printf '{"active":false}\n'
  exit 0
fi

cmdline=$(tr '\0' ' ' <"/proc/$pid/cmdline")

parse_geo() {
  local spec=$1
  [[ $spec =~ ^([0-9]+)x([0-9]+)\+(-?[0-9]+)\+(-?[0-9]+)$ ]] || return 1
  printf '{"active":true,"x":%s,"y":%s,"w":%s,"h":%s}\n' \
    "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
}

if [[ $cmdline =~ -region[[:space:]]+([^[:space:]]+) ]] && parse_geo "${BASH_REMATCH[1]}"; then
  exit 0
fi

if [[ $cmdline =~ -w[[:space:]]+([^[:space:]]+) ]] && parse_geo "${BASH_REMATCH[1]}"; then
  exit 0
fi

printf '{"active":true}\n'
