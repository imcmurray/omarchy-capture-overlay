#!/bin/bash
set -euo pipefail

PLUGIN_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$PLUGIN_DIR/bin/cam-lib"
REAL="${OMARCHY_PATH:-/usr/share/omarchy}/bin/omarchy-capture-screenrecording"

stop=false
fullscreen=false
webcam=false
for arg in "$@"; do
  case "$arg" in
  --stop-recording) stop=true ;;
  --fullscreen) fullscreen=true ;;
  --with-webcam | --webcam-device=*) webcam=true ;;
  esac
done

gsr_running() { pgrep -f '^gpu-screen-recorder( |$)' >/dev/null 2>/dev/null; }

recording=false
gsr_running && recording=true
if $stop || $recording; then
  if $stop && ! $recording; then
    "$PLUGIN_DIR/bin/stop-cam" || true
    exit 1
  fi

  filename=$(runtime_io read-stock-filename 2>/dev/null || true)

  pkill -SIGINT -f '^gpu-screen-recorder( |$)' 2>/dev/null || true
  count=0
  while gsr_running && ((count < 50)); do
    sleep 0.1
    count=$((count + 1))
  done
  gsr_running && pkill -9 -f '^gpu-screen-recorder( |$)' 2>/dev/null || true
  omarchy-shell -q omarchy.indicators refresh 2>/dev/null || true
  sleep 0.4

  if [[ -z $filename ]]; then
    cand=$(ls -t "${OMARCHY_SCREENRECORD_DIR:-$HOME/Videos}"/screenrecording-*.mp4 2>/dev/null | head -1 || true)
    filename=$(runtime_io verify-recording "${cand:-}" 2>/dev/null || true)
  fi
  runtime_io clear-stock-filename || true

  if [[ -n $filename ]]; then
    "$PLUGIN_DIR/bin/compose-cam" "$filename" || true
    preview=""
    if ffmpeg -hide_banner -loglevel quiet -y -ss 3 -i "$filename" -frames:v 1 -f image2pipe -vcodec png pipe:1 \
      | runtime_io write-file preview.png; then
      preview="$RUNTIME/preview.png"
    fi
    omarchy-notification-send "Screen recording saved" "Final render is ready (click to play)" \
      -t 10000 --image "${preview:-$filename}" --exec mpv -- "$filename"
    (sleep 2; runtime_io remove-file preview.png || true) &
    printf '%s\n' "$filename"
  else
    "$PLUGIN_DIR/bin/stop-cam" || true
  fi
  exit 0
fi

if $fullscreen || [[ ${OMARCHY_SCREENRECORD_USE_PORTAL:-false} == true ]]; then
  exec "$REAL" "$@"
fi

pick_args=()
$webcam && pick_args+=(--webcam-shape)
pick_out=$("$PLUGIN_DIR/pick.sh" "${pick_args[@]}") || {
  omarchy-notification-send -u critical -t 4000 "Screen recording cancelled" "Capture region was not selected."
  exit 1
}
mapfile -t pick_lines <<<"$pick_out"
geo=${pick_lines[0]:-}
shape=${pick_lines[1]:-rectangle}
[[ -n $geo ]] || exit 1

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf '%s\n' "$geo" >"$tmp/geo"

cat >"$tmp/omarchy-capture-region" <<'EOF'
#!/bin/bash
GEO=$(cat "$(dirname "$0")/geo")
MATCH=false
for arg in "$@"; do
  [[ $arg == --match-monitor ]] && MATCH=true
done
if $MATCH; then
  mon=$(hyprctl monitors -j | jq -r --arg geo "$GEO" '
    def format_geo:
      .x as $x | .y as $y |
      (.width / .scale | floor) as $w |
      (.height / .scale | floor) as $h |
      .transform as $t |
      if $t == 1 or $t == 3 then
        "\($x),\($y) \($h)x\($w)"
      else
        "\($x),\($y) \($w)x\($h)"
      end;
    .[] | select(format_geo == $geo) | .name' | head -1)
  if [[ -n $mon ]]; then
    printf 'monitor:%s\n' "$mon"
    exit 0
  fi
fi
printf '%s\n' "$GEO"
EOF
chmod +x "$tmp/omarchy-capture-region"

real_args=()
for arg in "$@"; do
  if $webcam && [[ $arg == --with-webcam || $arg == --webcam-device=* || $arg == --webcam-size=* ]]; then
    continue
  fi
  real_args+=("$arg")
done

# Only the fake region helper is prepended — never a fake mpv.
PATH="$tmp:$PATH" "$REAL" "${real_args[@]}"
