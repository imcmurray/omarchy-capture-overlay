# Omarchy capture overlay

A live capture overlay for Omarchy screen recordings. Pick a region with 1080p snap guides, drop a webcam pip that is actually in the file, crop and zoom the camera inside the shape, show key chords, and fade the saved clip in or out.

![Webcam pip on the grab, with crop handles](docs/preview.png)

Stock screenrecord stays stock. This plugin adds **With overlay + desktop + microphone audio**.

## What it adds

**Snap to 1080p.** Drag a region or click a size guide. 1080p, 720p, and 900p sit on the grab so the recording is the size you meant.

![1080p snap guides on the live grab](docs/picker-guides.png)

**Options on the grab.** Fade in, fade out, **Show keys**, pip border, and corner radius, then rectangle, square, circle, or oval. Esc from the next step comes back here.

![Shape and options panel](docs/shape-panel.png)

**A pip that records.** The live camera is what gpu-screen-recorder captures. Drag it to a corner. Super+Alt `[` / `]` resizes the frame. Oval rotates from the top knob.

**Crop and zoom the camera.** Pull the handles to focus the shot inside the shape. The pip stays the same size; the video zooms. Esc goes back.

![Crop handles zooming the camera inside the oval](docs/pip-zoom.png)

**Show keys** draws Super/Ctrl/Alt chords at the bottom of the grab (and in the recording). Bare typing stays hidden.

Fade in/out is ffmpeg on the saved file, not on the live preview. Border color comes from the theme.

## Install

```bash
omarchy plugin add https://github.com/imcmurray/omarchy-capture-overlay.git --enable
```

That clones the plugin, validates the manifest, and loads the overlay service. `omarchy plugin update` can fast-forward it later.

Alt+Print still uses stock screenrecord until you wire the three snippets in `config/`:

1. **Menu** — merge `config/omarchy-menu.jsonc` into `~/.config/omarchy/extensions/omarchy-menu.jsonc`. That keeps the stock screenrecord rows and adds **With overlay + desktop + microphone audio**, plus a stop row that waits for the fade render.
2. **Hyprland layers** — append `config/hyprland.lua` to `~/.config/hypr/hyprland.lua`.
3. **Bindings** — append `config/bindings.lua` to `~/.config/hypr/bindings.lua` (unbinds stock Alt+Print and Super+Alt `[` / `]` first, and installs the Show keys hook).

Then:

```bash
hyprctl reload
omarchy restart shell
```

## Use

1. **Alt+Print** → **With overlay + desktop + microphone audio**
2. Drag a region, or click a 1080p / 720p / 900p guide
3. Set fade, **Show keys**, border, and corner radius, then click a shape (Esc from the next step returns here)
4. Drag the pip. Pull the handles to crop and zoom the camera inside the shape (oval also rotates from the top knob). If more than one camera is plugged in, pick it from the menu under the preview. Super+Alt `[` / `]` resizes the pip. **Esc** to go back
5. **Enter** for 3–2–1, then record
6. **Alt+Print** again to stop (waits for the final render, then toasts)

Stock **With desktop + microphone audio + webcam** is still the Omarchy pip.

**Show keys** needs the bindings.lua hook above so chords still show after 3–2–1, when the overlay no longer has keyboard focus.

## Update

```bash
omarchy plugin update ianm.capture-overlay
```

## Remove

```bash
omarchy plugin remove ianm.capture-overlay
```

That disables and deletes the plugin checkout. Remove the three `config/` snippets from your menu, Hyprland, and bindings if you want Alt+Print back on stock screenrecord, then `hyprctl reload`.

## Layout

| Path | Role |
| --- | --- |
| `Service.qml` | Overlay service: picker, IPC, pip drag |
| `CamPreview.qml` | Qt Multimedia live camera + countdown surface |
| `PickerModel.js` | Snap guides and hit testing |
| `record.sh` / `pick.sh` | Menu entry; region IPC |
| `bin/compose-cam` | Fade in/out on the saved file |
| `bin/test-core` | Script and picker unit tests |
| `bin/test-overlay` | Unit tests plus idle / menu / picker checks |
| `ROADMAP.md` | Later work: in-grab options panel (fades, length, countdown) |

## License

MIT
