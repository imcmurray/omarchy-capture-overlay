# Later work

Written after v1.3.19, with the core cleaned up and working. Do not implement
this until we come back on purpose. The next feature is **one in-grab options
panel after the region is confirmed** — not a pile of separate knobs.

## Current flow

1. Drag / snap / adjust the grab.
2. Enter confirms the region.
3. **Webcam recordings only:** `pickPhase = "shape"` shows Rectangle / Circle
   plus Fade in / Fade out, then the live pip, then 3–2–1.
4. **Everything else:** confirm jumps straight to 3–2–1. No fades, no options.

Fades are ffmpeg post on the saved file (`bin/compose-cam`). They are **not**
applied to the live pip. Flags live in `$XDG_RUNTIME_DIR/omarchy-cam-mix.env`
(`FADE_IN`, `FADE_OUT`, `FADE_SEC`, default 2.5s). `compose-cam` no-ops if
that recipe is missing, so non-webcam recordings cannot fade today.
`start-cam` is what writes the recipe, and it only runs on the webcam path.

The live QML pip **is** what gpu-screen-recorder captures. There is no sidecar
mix and there must not be one again (it duplicated the pip).

## The panel

After region confirm, show a compact options panel **on the grab** (same place
as today’s shape picker). One panel for every recording.

| Row | When | What |
| --- | --- | --- |
| Shape | Webcam only | Rectangle / Circle (already exists) |
| Fade in / Fade out | Always | Checkboxes (already exist, webcam-only today) |
| Fade length | Always, if a fade is on | Three presets, not a free number |
| Countdown | Always | 3 / 5 / off |

Enter continues: webcam → place pip → countdown (or skip if off); no webcam →
countdown (or start immediately if off). Esc still cancels.

Keep it on the grab. Do not add a settings page, a menu of extra rows, or
new keybindings for these.

## Do first (in this order)

### 1. Fades on every recording

Same checkboxes, including Alt+Print rows that are not “+ webcam”.

That means writing the fade recipe even when there is no camera, and running
`compose-cam` on stop for those files too. Stop must still go through plugin
`record.sh --stop-recording` (compose, then toast). Stock stop skips fades.

Default length stays 2.5s until (2) exists.

### 2. Fade length presets

Three choices, not a slider or typed seconds:

- Short (~1.0s)
- Medium (2.5s, default)
- Long (~4.0s)

2.5s is easy to miss on a dark grab; Long is the “I want to see it” option.
`compose-cam` already clamps so two fades cannot exceed the clip.

### 3. Countdown 3 / 5 / off

The 3–2–1 surface already exists (`ianm-capture-countdown`, Overlay order 40;
webcam video is parked off-screen so it cannot cover the digits). Reuse it.
Off skips straight to record. 5 is the same surface with a longer timer.

## Do later (after the panel exists)

- **Mirror.** Dedicated decision, not a drive-by toggle. Because the live pip
  is the grab, mirroring the preview **will** appear in the saved file. Live-
  only mirror is not available without a second camera consumer, and a C920
  cannot be opened twice.
- **Hide cursor.** gpu-screen-recorder flag on the record command. Separate
  from the panel if it stays a simple checkbox; fine to add as a panel row
  once the panel is there.
- **Pip border.** Done in 1.4.0: color + Off/Thin/Medium/Thick on the shape
  panel, drawn on both rectangle and circle (captured in the recording).
- **Countdown beep.** Easy and polarizing; optional, default off.

## Do not do

- Titles / end cards
- Green screen / chroma key
- A second camera pipeline, v4l2loopback, or sidecar mix
- PATH-wrapping `mpv`
- Matching stock `WebcamOverlay-*` window rules
- Anything under `/usr/share/omarchy/`
- Wrapping `VideoOutput` in `layer.enabled` (that froze the camera and left
  `/dev/video0` held)

## Files to touch when we come back

| File | Why |
| --- | --- |
| `Service.qml` | New `pickPhase` (or reuse `"shape"` for all recordings). Fade length + countdown properties. Options panel UI. `confirmRegion` must not skip the panel when `askWebcamShape` is false. |
| `pick.sh` / `record.sh` | Non-webcam picks need the same finish-pick fade flags. |
| `bin/start-cam` or a small `bin/save-fades` | Recipe must exist without a camera. |
| `bin/cam-lib` | Persist `FADE_SEC` from the preset; maybe countdown (countdown can stay QML-only). |
| `bin/compose-cam` | Already fade-only; should keep working if the recipe has fades and no pip geometry. |
| `bin/test-core` | Recipe-without-webcam; each fade length against a generated clip; compose no-op when both fades are off. |
| `bin/test-overlay` | Options panel appears on a non-webcam pick, cancel still unmaps. |

Hard-won constraints to keep: empty mask on `ianm-cam-preview` (visual only);
overlay order overlay=1, countdown=40, menu=50; never call stock stop; menu
jsonc overrides must keep `icon` / `label` / `when` or the stop row shows the
raw id.
