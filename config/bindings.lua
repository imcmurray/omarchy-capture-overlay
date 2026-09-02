-- Close a leftover capture picker before opening the screenrecord menu.
-- Note: ALT+PRINT was previously bound to Screenrecording.
hl.unbind("ALT + PRINT")
o.bind("ALT + PRINT", "Screenrecording", "omarchy-shell capture-overlay cancel >/dev/null 2>&1; omarchy-capture-screenrecording --stop-recording || omarchy-menu toggle trigger.capture.screenrecord")

-- SUPER+ALT+[ / ] resize the live webcam pip.
hl.unbind("SUPER + ALT + code:34")
hl.unbind("SUPER + ALT + code:35")
o.bind("SUPER + ALT + code:34", "Make webcam overlay smaller", os.getenv("HOME") .. "/.config/omarchy/plugins/ianm.capture-overlay/bin/omarchy-capture-webcam-resize smaller")
o.bind("SUPER + ALT + code:35", "Make webcam overlay larger", os.getenv("HOME") .. "/.config/omarchy/plugins/ianm.capture-overlay/bin/omarchy-capture-webcam-resize larger")
