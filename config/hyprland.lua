-- Capture-region overlay should appear instantly, with no layer fade.
-- Keep it above the camera surface, but below the Omarchy menu so Alt+Print
-- rows stay clickable even if a picker is still mapped.
-- Blur the dimmed backdrop so shape/camera pickers stand out (Omarchy leaves
-- decoration.blur off; new_optimizations keeps opaque windows cheap).
hl.config({
  decoration = {
    blur = {
      enabled = true,
      size = 6,
      passes = 2,
      new_optimizations = true,
      popups = false,
    },
  },
})
hl.layer_rule({ match = { namespace = "ianm-capture-overlay" }, no_anim = true, animation = "none", order = 1, blur = true, ignore_alpha = 0.08 })
hl.layer_rule({ match = { namespace = "ianm-capture-live" }, no_anim = true, animation = "none", order = 1 })
hl.layer_rule({ match = { namespace = "omarchy-menu" }, order = 50 })
hl.layer_rule({ match = { namespace = "ianm-capture-countdown" }, no_anim = true, animation = "none", order = 40 })
-- Camera stays on Top (below Overlay) so 3-2-1 on Overlay is in front.
hl.layer_rule({ match = { namespace = "ianm-cam-preview" }, no_anim = true, animation = "none", order = 0 })
