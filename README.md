# Capture overlay for Omarchy

Stock screenrecord still uses slurp. This is the extra row: a live grab, a webcam pip that is actually in the file, and a camera you can crop and zoom.

![Screenrecord menu with the overlay row selected](preview.png)

**Alt+Print → With overlay + desktop + microphone audio.** The four stock rows stay on Omarchy.

## Snap the region. Don't guess.

Drag a grab or click 1080p, 720p, or 900p. The guides sit on the glass, so the file is the size you meant.

![1080p snap guides](docs/picker-guides.png)

## Dress the shot on the grab

Fade in, fade out, **Show keys**, pip border, corner radius. Then rectangle, square, circle, or oval. Esc from the next step comes back here.

![Options and shape panel](docs/shape-panel.png)

## Zoom the camera, not the pip

The live camera is what gpu-screen-recorder captures. Drag the pip to a corner. Super+Alt `[` / `]` resizes the frame. Pull the handles to focus the shot inside the shape — the pip stays put, the video punches in. Oval rotates from the top knob.

![Camera zoomed inside the same oval](docs/pip-zoom.png)

**Show keys** draws Super/Ctrl/Alt chords at the bottom of the grab and in the recording. Bare typing stays hidden.

Fades are ffmpeg on the saved file. Border color comes from the theme.

## Install

```bash
omarchy plugin add https://github.com/imcmurray/omarchy-capture-overlay.git --enable
```

That clones the plugin, validates the manifest, and loads the overlay service.

Alt+Print still uses stock screenrecord until you wire the three snippets in `config/`:

1. **Menu** — merge `config/omarchy-menu.jsonc` into `~/.config/omarchy/extensions/omarchy-menu.jsonc`. Stock rows stay. You get **With overlay + desktop + microphone audio**, plus a stop row that waits for the fade render.
2. **Hyprland layers** — append `config/hyprland.lua` to `~/.config/hypr/hyprland.lua`.
3. **Bindings** — append `config/bindings.lua` to `~/.config/hypr/bindings.lua` (unbinds stock Alt+Print and Super+Alt `[` / `]` first, and installs the Show keys hook).

```bash
hyprctl reload
omarchy restart shell
```

## Use

1. **Alt+Print** → **With overlay + desktop + microphone audio**
2. Drag a region, or click a 1080p / 720p / 900p guide
3. Set fade, **Show keys**, border, and corners, then click a shape
4. Drag the pip. Pull the handles to crop and zoom. Super+Alt `[` / `]` resizes. Esc goes back
5. **Enter** for 3–2–1, then record
6. **Alt+Print** to stop — waits for the final render, then toasts

The Show keys hook in bindings.lua is what keeps chords on screen after 3–2–1, when the overlay no longer has keyboard focus.

## Update

```bash
omarchy plugin update ianm.capture-overlay
```

## Remove

```bash
omarchy plugin remove ianm.capture-overlay
```

Then delete the three `config/` snippets if you want Alt+Print back on stock screenrecord, and `hyprctl reload`.

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
