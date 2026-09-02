#!/bin/bash
set -euo pipefail

ask_shape=false
for arg in "$@"; do
  case "$arg" in
  --webcam-shape) ask_shape=true ;;
  esac
done

sel=$(mktemp)
done=$(mktemp)
: >"$sel"
: >"$done"
trap 'rm -f "$sel" "$done"' EXIT

payload=$(python3 -c 'import json,sys; print(json.dumps({"selectionFile": sys.argv[1], "doneFile": sys.argv[2], "askWebcamShape": sys.argv[3]=="1"}))' "$sel" "$done" "$([[ $ask_shape == true ]] && echo 1 || echo 0)")

# The menu holds an exclusive keyboard grab. Wait for it to unmap before
# this overlay asks for the same grab, or the picker never takes input.
sleep 0.2
ok=false
for _ in 1 2 3 4 5 6 7 8; do
  if omarchy-shell capture-overlay pick "$payload" >/dev/null; then
    ok=true
    break
  fi
  sleep 0.1
done
if ! $ok; then
  echo "capture overlay picker is not running" >&2
  omarchy-notification-send -u critical -t 4000 "Webcam recording" "Capture overlay picker did not start."
  exit 1
fi

for _ in $(seq 1 12000); do
  if [[ -s $done ]]; then
    status=$(<"$done")
    [[ $status == ok ]] || exit 1
    geo=$(sed -n '1p' "$sel")
    shape=$(sed -n '2p' "$sel")
    [[ -n $geo ]] || exit 1
    printf '%s\n' "$geo"
    [[ -n $shape ]] && printf '%s\n' "$shape"
    exit 0
  fi
  sleep 0.05
done

omarchy-shell capture-overlay cancel >/dev/null 2>&1 || true
echo "timed out waiting for a capture region" >&2
exit 1
