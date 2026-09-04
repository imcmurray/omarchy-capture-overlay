# Capture overlay for Omarchy

A fifth Screenrecord row. Stock Omarchy stays stock.

![Screenrecord menu with the overlay row selected](preview.png)

**Alt+Print → With overlay + desktop + microphone audio.** That row opens a live grab with 1080p snap guides, a webcam pip that is actually in the file, and handles that crop and zoom the camera.

![Place the pip, then crop it](docs/pip-place.png)

Pull the handles to focus the shot inside the shape. The pip stays put; the video punches in. Super+Alt `[` / `]` resizes the frame. Oval rotates from the top knob.

![Camera zoomed inside the same oval](docs/pip-zoom.png)

On the grab you also get fade in/out, **Show keys** (Super/Ctrl/Alt chords; bare typing stays hidden), pip border, and corner radius, then rectangle, square, circle, or oval. Fades are ffmpeg on the saved file. Border color comes from the theme.

## Install

```bash
omarchy plugin add https://github.com/imcmurray/omarchy-capture-overlay.git --enable
```

Alt+Print still uses stock screenrecord until you wire the three snippets in `config/`:

1. **Menu** — merge `config/omarchy-menu.jsonc` into `~/.config/omarchy/extensions/omarchy-menu.jsonc`
2. **Hyprland layers** — append `config/hyprland.lua` to `~/.config/hypr/hyprland.lua`
3. **Bindings** — append `config/bindings.lua` to `~/.config/hypr/bindings.lua` (unbinds stock Alt+Print and Super+Alt `[` / `]` first, and installs the Show keys hook)

```bash
hyprctl reload
omarchy restart shell
```

The marketplace card uses the same root `preview.png` as the hero above.

## Use

1. **Alt+Print** → **With overlay + desktop + microphone audio**
2. Drag a region, or click a 1080p / 720p / 900p guide
3. Set fade, **Show keys**, border, and corners, then click a shape
4. Drag the pip. Pull the handles to crop and zoom. Esc goes back
5. **Enter** for 3–2–1, then record
6. **Alt+Print** to stop — waits for the final render, then toasts

## Update

```bash
omarchy plugin update ianm.capture-overlay
```

## Remove

```bash
omarchy plugin remove ianm.capture-overlay
```

Then delete the three `config/` snippets if you want Alt+Print back on stock screenrecord, and `hyprctl reload`.

## License

MIT
