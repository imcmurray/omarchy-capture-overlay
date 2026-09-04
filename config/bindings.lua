-- Close a leftover capture picker before opening the screenrecord menu.
-- Note: ALT+PRINT was previously bound to Screenrecording.
hl.unbind("ALT + PRINT")
o.bind("ALT + PRINT", "Screenrecording", "omarchy-shell capture-overlay cancel >/dev/null 2>&1; $HOME/.config/omarchy/plugins/ianm.capture-overlay/record.sh --stop-recording || omarchy-menu toggle trigger.capture.screenrecord")

-- Super+Alt [ / ] resize the live pip. Crop stays on the place-phase handles.
hl.unbind("SUPER + ALT + code:34")
hl.unbind("SUPER + ALT + code:35")
o.bind("SUPER + ALT + code:34", "Make webcam overlay smaller", "$HOME/.config/omarchy/plugins/ianm.capture-overlay/bin/omarchy-capture-webcam-resize smaller")
o.bind("SUPER + ALT + code:35", "Make webcam overlay larger", "$HOME/.config/omarchy/plugins/ianm.capture-overlay/bin/omarchy-capture-webcam-resize larger")

-- Show keys HUD. No-op unless the overlay has created the .on flag (Show keys
-- while picking or recording). The whole handler is pcall'd so a bad event
-- shape cannot pop Hyprland's Lua error overlay while you type.
do
  local dir = os.getenv("XDG_RUNTIME_DIR")
  if dir then
  local path = dir .. "/ianm-capture-overlay/keys"
  local onpath = dir .. "/ianm-capture-overlay/keys.on"
  local linux = {
    [1] = "Esc", [14] = "Backspace", [15] = "Tab", [28] = "Enter", [57] = "Space",
    [12] = "-", [13] = "=", [26] = "[", [27] = "]", [39] = ";", [40] = "'",
    [41] = "`", [43] = "\\", [51] = ",", [52] = ".", [53] = "/",
    [59] = "F1", [60] = "F2", [61] = "F3", [62] = "F4", [63] = "F5", [64] = "F6",
    [65] = "F7", [66] = "F8", [67] = "F9", [68] = "F10", [87] = "F11", [88] = "F12",
    [99] = "Print", [102] = "Home", [103] = "Up", [104] = "PgUp",
    [105] = "Left", [106] = "Right", [107] = "End", [108] = "Down", [109] = "PgDn",
    [110] = "Insert", [111] = "Delete",
    [16] = "Q", [17] = "W", [18] = "E", [19] = "R", [20] = "T", [21] = "Y",
    [22] = "U", [23] = "I", [24] = "O", [25] = "P",
    [30] = "A", [31] = "S", [32] = "D", [33] = "F", [34] = "G", [35] = "H",
    [36] = "J", [37] = "K", [38] = "L",
    [44] = "Z", [45] = "X", [46] = "C", [47] = "V", [48] = "B", [49] = "N", [50] = "M",
    [2] = "1", [3] = "2", [4] = "3", [5] = "4", [6] = "5",
    [7] = "6", [8] = "7", [9] = "8", [10] = "9", [11] = "0",
  }
  local super = { [125] = true, [126] = true }
  local ctrl = { [29] = true, [97] = true }
  local alt = { [56] = true, [100] = true }
  local shift = { [42] = true, [54] = true }
  local held = {}
  local function linux_code(code)
    if type(code) ~= "number" then
      return nil
    end
    if code >= 8 then
      return code - 8
    end
    return code
  end
  local function parse(a, b, c)
    if type(a) == "number" then
      return linux_code(a), tonumber(c)
    end
    if type(a) == "table" then
      local code = tonumber(a.keycode) or tonumber(a.key) or tonumber(a.code) or tonumber(a[1])
      local state = tonumber(a.state) or tonumber(a.status) or tonumber(a[3]) or tonumber(b)
      return linux_code(code), state
    end
    return nil, nil
  end
  local function handle(a, b, c)
    local armed = io.open(onpath, "r")
    if not armed then
      return
    end
    armed:close()
    local code, state = parse(a, b, c)
    if not code then
      return
    end
    if state == 0 then
      held[code] = nil
      return
    end
    held[code] = true
    if state ~= 1 then
      return
    end
    if super[code] or ctrl[code] or alt[code] or shift[code] then
      return
    end
    local name = linux[code]
    if not name then
      return
    end
    local function any(map)
      for k in pairs(map) do
        if held[k] then
          return true
        end
      end
      return false
    end
    local parts = {}
    if any(super) then parts[#parts + 1] = "Super" end
    if any(ctrl) then parts[#parts + 1] = "Ctrl" end
    if any(alt) then parts[#parts + 1] = "Alt" end
    local special = #name > 1
    if any(shift) and (#parts > 0 or special) then
      parts[#parts + 1] = "Shift"
    end
    if #parts == 0 and not special then
      return
    end
    parts[#parts + 1] = name
    local f = io.open(path, "w")
    if f then
      f:write(table.concat(parts, " + "))
      f:close()
    end
  end
  if _G.ianm_capture_keys_sub and _G.ianm_capture_keys_sub.remove then
    pcall(function()
      _G.ianm_capture_keys_sub:remove()
    end)
  end
  _G.ianm_capture_keys_sub = hl.on("input.keyboard.key", function(...)
    pcall(handle, ...)
  end)
  end
end
