# Omarchy capture overlay

Interactive screen-record picker for [Omarchy](https://omarchy.org/) (Hyprland + Quickshell).

Replaces the stock slurp region picker with a live grab frame, 1080p snap guides, and a webcam pip that can be a rectangle or a circle. The live camera stays out of gpu-screen-recorder (`no_screen_share`); a sidecar is mixed in after you stop.

## Features

- Drag a region with 1080p / 720p / 900p snap guides and draggable edges
- Webcam shape after confirm: rectangle or circle
- Live pip in the grab; drag it to a corner; Super+Alt `[` / `]` eases between sizes
- 3–2–1 replaces the pip, then the camera comes back
- Desktop audio + microphone on the webcam menu row
- Mix uses the same circle (or rectangle) as the live preview

## Install

```bash
git clone https://github.com/imcmurray/omarchy-capture-overlay \
  ~/.config/omarchy/plugins/ianm.capture-overlay
```

Then merge the snippets in `config/`:

1. **Menu** — copy or merge `config/omarchy-menu.jsonc` into `~/.config/omarchy/extensions/omarchy-menu.jsonc` so Alt+Print recording rows call this plugin’s `record.sh`.
2. **Hyprland layers** — append `config/hyprland.lua` to `~/.config/hypr/hyprland.lua`.
3. **Bindings** — append `config/bindings.lua` to `~/.config/hypr/bindings.lua` (unbinds stock Alt+Print and Super+Alt `[` / `]` first).

Reload:

```bash
hyprctl reload
omarchy restart shell
```

## Use

1. **Alt+Print** → **With desktop + microphone audio + webcam**
2. Drag a region (click a size guide or pull the edges)
3. Pick **Rectangle** or **Circle**
4. Drag the pip to a corner; **Super+Alt+[`** / **`]** to resize
5. **Enter** for 3–2–1, then record
6. **Alt+Print** again to stop

Without webcam, the same picker still wraps the other screenrecord menu rows.

## Layout

| Path | Role |
| --- | --- |
| `Service.qml` | Overlay service: picker, IPC, pip drag, mix hooks |
| `CamPreview.qml` | Qt Multimedia live camera + countdown surface |
| `PickerModel.js` | Snap guides and hit testing |
| `record.sh` / `pick.sh` | Menu entry; region IPC |
| `bin/compose-cam` | Mix sidecar onto the grab |
| `bin/test-overlay` | Idle / menu / picker checks |

## License

MIT
