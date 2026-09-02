#!/bin/bash
set -euo pipefail

PLUGIN_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
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

if $stop || pgrep -f '^gpu-screen-recorder( |$)' >/dev/null 2>/dev/null; then
  mapfile -t _out < <("$REAL" "$@" || true)
  filename=""
  if ((${#_out[@]} > 0)); then
    filename=${_out[-1]}
  fi
  if [[ -n $filename && -f $filename ]]; then
    "$PLUGIN_DIR/bin/compose-cam" "$filename" || true
    printf '%s\n' "$filename"
  else
    "$PLUGIN_DIR/bin/stop-cam" || true
  fi
  exit 0
fi

if $fullscreen || [[ ${OMARCHY_SCREENRECORD_USE_PORTAL:-false} == true ]]; then
  exec "$REAL" "$@"
fi

if $webcam; then
  pick_out=$("$PLUGIN_DIR/pick.sh" --webcam-shape) || {
    omarchy-notification-send -u critical -t 4000 "Screen recording cancelled" "Capture region was not selected."
    exit 1
  }
else
  pick_out=$("$PLUGIN_DIR/pick.sh") || {
    omarchy-notification-send -u critical -t 4000 "Screen recording cancelled" "Capture region was not selected."
    exit 1
  }
fi
mapfile -t pick_lines <<<"$pick_out"
geo=${pick_lines[0]:-}
shape=${pick_lines[1]:-rectangle}
[[ -n $geo ]] || exit 1
printf '%s\n' "$shape" >"${XDG_RUNTIME_DIR:-/tmp}/omarchy-webcam-shape"

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
