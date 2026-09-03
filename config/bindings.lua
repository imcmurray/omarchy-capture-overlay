-- Close a leftover capture picker before opening the screenrecord menu.
-- Note: ALT+PRINT was previously bound to Screenrecording.
hl.unbind("ALT + PRINT")
o.bind("ALT + PRINT", "Screenrecording", "omarchy-shell capture-overlay cancel >/dev/null 2>&1; $HOME/.config/omarchy/plugins/ianm.capture-overlay/record.sh --stop-recording || omarchy-menu toggle trigger.capture.screenrecord")

-- Super+Alt [ / ] resize the live pip. Crop stays on the place-phase handles.
hl.unbind("SUPER + ALT + code:34")
hl.unbind("SUPER + ALT + code:35")
o.bind("SUPER + ALT + code:34", "Make webcam overlay smaller", "$HOME/.config/omarchy/plugins/ianm.capture-overlay/bin/omarchy-capture-webcam-resize smaller")
o.bind("SUPER + ALT + code:35", "Make webcam overlay larger", "$HOME/.config/omarchy/plugins/ianm.capture-overlay/bin/omarchy-capture-webcam-resize larger")
