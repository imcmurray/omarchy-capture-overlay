#!/bin/bash
set -euo pipefail

PLUGIN_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$PLUGIN_DIR/bin/cam-lib"

ask_shape=false
for arg in "$@"; do
  case "$arg" in
  --webcam-shape) ask_shape=true ;;
  esac
done

payload=$(python3 -c 'import json,sys; print(json.dumps({"askWebcamShape": sys.argv[1]=="1"}))' "$([[ $ask_shape == true ]] && echo 1 || echo 0)")

# The menu holds an exclusive keyboard grab. Wait for it to unmap before
# this overlay asks for the same grab, or the picker never takes input.
sleep 0.2
ok=false
session=""
for _ in 1 2 3 4 5 6 7 8; do
  out=$(omarchy-shell capture-overlay pick "$payload" 2>/dev/null) || out=""
  session=$(python3 -c 'import json,sys,re
t=sys.stdin.read().strip()
try:
    s=json.loads(t).get("session","")
except Exception:
    s=""
print(s if re.fullmatch(r"[0-9a-f]{16,32}", s or "") else "")
' <<<"$out")
  if [[ -n $session ]]; then
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

sel="$RUNTIME/p-${session}.sel"
donef="$RUNTIME/p-${session}.done"

for _ in $(seq 1 12000); do
  if [[ -s $donef ]]; then
    status=$(<"$donef")
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
