import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "PickerModel.js" as Picker

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property bool recording: false
  property bool hasRegion: false
  property int regionX: 0
  property int regionY: 0
  property int regionW: 0
  property int regionH: 0
  property bool forced: false

  property bool picking: false
  property string pickPhase: "idle" // idle, drag, adjust, resize, move, shape, place, countdown
  property string pickHandle: ""
  property string pickScreenName: ""
  property int pickSX: 0
  property int pickSY: 0
  property int pickSW: 0
  property int pickSH: 0
  property int anchorX: 0
  property int anchorY: 0
  property int dirX: 1
  property int dirY: 1
  property int pressX: 0
  property int pressY: 0
  property var pressRect: ({ x: 0, y: 0, w: 0, h: 0 })
  property var ghosts: []
  property string snappedLabel: ""
  property string hoverHandle: ""
  property string hoverGhost: ""
  property string selectionFile: ""
  property string doneFile: ""
  property bool askWebcamShape: false
  property string webcamShape: "rectangle"
  property bool fadeIn: false
  property bool fadeOut: false
  property bool showKeys: false
  property string keyHudText: ""
  property string pipBorderColorKey: "accent"
  property string pipBorderWidthKey: "medium"
  property real pipCornerFrac: 0
  property bool pipPrefsLoaded: false
  property var themePalette: ({})
  property int countdownValue: 3
  property int camX: 0
  property int camY: 0
  property int camW: 0
  property int camH: 0
  property real camRot: 0
  property real camInsetL: 0
  property real camInsetT: 0
  property real camInsetR: 0
  property real camInsetB: 0
  property bool camAnimating: false
  property bool camDidDrag: false
  property bool camDragging: false
  property bool camResizing: false
  property bool camPreviewActive: false
  property bool wasRecording: false
  property string cameraId: ""
  property string cameraName: ""
  property bool cameraMenuOpen: false

  readonly property var camScreen: {
    var screens = Quickshell.screens
    var name = root.pickScreenName
    for (var i = 0; i < screens.length; i++) {
      if (!name || screens[i].name === name)
        return screens[i]
    }
    return screens.length ? screens[0] : null
  }

  readonly property int borderWidth: Math.max(3, Style.space(3))
  readonly property int contrastWidth: Math.max(2, Style.space(2))
  readonly property int framePad: borderWidth + contrastWidth
  readonly property int cornerLength: Math.max(22, Style.space(22))
  readonly property color frameColor: Color.accent
  readonly property color contrastColor: Color.background
  readonly property color dimColor: Util.alpha(Color.background, 0.32)
  readonly property bool pickerScrim: root.pickPhase === "shape" || root.cameraMenuOpen
  property real scrimAmount: root.pickerScrim ? 1 : 0
  Behavior on scrimAmount { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }
  readonly property color scrimColor: Util.alpha(Color.background, 0.32 + root.scrimAmount * 0.18)
  readonly property color pipBorderColor: root.pipBorderColorFor(root.pipBorderColorKey)
  readonly property int pipBorderPx: root.pipBorderPxFor(root.pipBorderWidthKey)
  readonly property int pipBorderPreview: root.pipBorderPx > 0 ? Math.max(2, Math.min(5, root.pipBorderPx)) : 0
  readonly property int pipCornerPx: Picker.usesCornerRadius(root.webcamShape)
    ? Picker.cornerPx(root.pipCornerFrac, root.camW, root.camH)
    : 0
  readonly property string pipCornerLabel: {
    if (root.pipCornerFrac <= 0)
      return "Off"
    var w = root.hasRegion ? root.regionW : 0
    var h = root.hasRegion ? root.regionH : 0
    var side = Math.min(w, h)
    var px = Picker.cornerPx(root.pipCornerFrac, side, side)
    return px > 0 ? (px + " px") : "Off"
  }
  readonly property string pipPrefsPath: {
    var home = Quickshell.env("HOME") || ""
    return home ? home + "/.config/omarchy/ianm.capture-overlay.json" : ""
  }
  readonly property string keyHudPath: {
    var dir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    return dir + "/omarchy-capture-keys"
  }
  readonly property bool pickUiLocked: root.pickPhase === "shape" || root.pickPhase === "place" || root.pickPhase === "countdown"

  readonly property var currentRect: ({ x: regionX, y: regionY, w: regionW, h: regionH })
  readonly property string sizeLabel: {
    if (!root.hasRegion) return "Drag to select"
    var tag = root.snappedLabel || Picker.matchingLabel(root.currentRect)
    return (tag ? tag + "  " : "") + root.regionW + " × " + root.regionH
  }

  readonly property string pluginDir: {
    if (root.manifest && root.manifest.__sourceDir)
      return String(root.manifest.__sourceDir).replace(/\/$/, "")
    var url = Qt.resolvedUrl(".").toString()
    if (url.indexOf("file://") === 0)
      url = decodeURIComponent(url.substring(7))
    return url.replace(/\/$/, "")
  }
  readonly property string statusScript: root.pluginDir + "/status.sh"

  Loader {
    id: camEngine
    active: root.camPreviewActive && root.camW > 0 && !!root.camScreen
    source: Qt.resolvedUrl("CamPreview.qml")
    onLoaded: {
      item.camScreen = Qt.binding(function() { return root.camScreen })
      item.camX = Qt.binding(function() { return root.camX })
      item.camY = Qt.binding(function() { return root.camY })
      item.camW = Qt.binding(function() { return root.camW })
      item.camH = Qt.binding(function() { return root.camH })
      item.camRot = Qt.binding(function() { return root.webcamShape === "oval" ? root.camRot : 0 })
      item.camInsetL = Qt.binding(function() { return root.camInsetL })
      item.camInsetT = Qt.binding(function() { return root.camInsetT })
      item.camInsetR = Qt.binding(function() { return root.camInsetR })
      item.camInsetB = Qt.binding(function() { return root.camInsetB })
      item.webcamShape = Qt.binding(function() { return root.webcamShape })
      item.showCountdown = Qt.binding(function() { return root.pickPhase === "countdown" })
      item.countdownValue = Qt.binding(function() { return root.countdownValue })
      item.pipBorderColor = Qt.binding(function() { return root.pipBorderColor })
      item.pipBorderWidth = Qt.binding(function() { return root.pipBorderPx })
      item.pipRadius = Qt.binding(function() { return root.pipCornerPx })
      item.cameraId = Qt.binding(function() { return root.cameraId })
      item.cameraName = Qt.binding(function() { return root.cameraName })
      item.deviceResolved.connect(function(id, name) { root.rememberCamera(id, name) })
      item.failed.connect(function() { root.camPreviewActive = false })
      item.cameraReady = true
    }
  }

  function onCaptureStopped() {
    root.stopWebcamPreview()
  }

  function applyStatus(raw) {
    var parsed
    try {
      parsed = JSON.parse(String(raw || "{}"))
    } catch (e) {
      return
    }

    var active = parsed.active === true
    if (root.wasRecording && !active)
      root.onCaptureStopped()
    root.wasRecording = active
    root.recording = active
    if (root.picking)
      return

    var nextHas = active && isFinite(parsed.x) && isFinite(parsed.y)
      && isFinite(parsed.w) && isFinite(parsed.h)
      && parsed.w > 0 && parsed.h > 0

    if (nextHas) {
      root.forced = false
      root.setRegion(parsed.x, parsed.y, parsed.w, parsed.h, Picker.matchingLabel(parsed))
      return
    }

    if (root.forced)
      return

    root.hasRegion = false
  }

  function setRegion(x, y, w, h, label) {
    var r = root.pickSW > 0
      ? Picker.clampRect({ x: x, y: y, w: w, h: h }, root.pickSX, root.pickSY, root.pickSW, root.pickSH)
      : { x: Math.round(x), y: Math.round(y), w: Math.round(w), h: Math.round(h) }
    root.hasRegion = r.w > 0 && r.h > 0
    root.regionX = r.x
    root.regionY = r.y
    root.regionW = r.w
    root.regionH = r.h
    root.snappedLabel = label || Picker.matchingLabel(r)
    root.refreshGhosts(r)
  }

  function refreshGhosts(rect) {
    if (!root.picking || root.pickSW <= 0) {
      root.ghosts = []
      return
    }
    var list = Picker.ghosts(root.anchorX, root.anchorY, root.dirX, root.dirY, root.pickSX, root.pickSY, root.pickSW, root.pickSH)
    root.ghosts = Picker.visibleGhosts(list, rect || (root.hasRegion ? { x: root.regionX, y: root.regionY, w: root.regionW, h: root.regionH } : null))
  }

  function lockScreen(screen) {
    root.pickScreenName = screen.name || ""
    root.pickSX = screen.x
    root.pickSY = screen.y
    root.pickSW = screen.width
    root.pickSH = screen.height
  }

  function showForced(payloadJson) {
    var parsed
    try {
      parsed = JSON.parse(String(payloadJson || "{}"))
    } catch (e) {
      return "error"
    }
    if (!isFinite(parsed.x) || !isFinite(parsed.y)
        || !isFinite(parsed.w) || !isFinite(parsed.h)
        || parsed.w <= 0 || parsed.h <= 0)
      return "error"
    root.forced = true
    root.picking = false
    root.setRegion(parsed.x, parsed.y, parsed.w, parsed.h, parsed.label || "")
    return "ok"
  }

  function hideForced() {
    root.forced = false
    if (!root.recording && !root.picking)
      root.hasRegion = false
    return "ok"
  }

  function startPick(payloadJson) {
    var parsed = ({})
    try {
      parsed = JSON.parse(String(payloadJson || "{}"))
    } catch (e) {
      parsed = ({})
    }
    if (root.picking && root.doneFile && root.doneFile !== String(parsed.doneFile || ""))
      root.finishPick(false)
    root.selectionFile = String(parsed.selectionFile || "")
    root.doneFile = String(parsed.doneFile || "")
    root.askWebcamShape = parsed.askWebcamShape === true || parsed.askWebcamShape === "true"
    root.webcamShape = "rectangle"
    root.resetCamView()
    root.fadeIn = false
    root.fadeOut = false
    root.countdownValue = 3
    countdownTimer.stop()
    root.picking = true
    root.pickPhase = "idle"
    root.pickHandle = ""
    root.hoverHandle = ""
    root.hoverGhost = ""
    root.snappedLabel = ""
    root.hasRegion = false
    root.forced = false
    root.ghosts = []
    root.stopWebcamPreview()
    var focused = Hyprland.focusedMonitor
    if (focused) {
      root.pickScreenName = focused.name || ""
      root.pickSX = focused.x
      root.pickSY = focused.y
      root.pickSW = Math.round(focused.width / (focused.scale || 1))
      root.pickSH = Math.round(focused.height / (focused.scale || 1))
    }
    return "ok"
  }

  function pipBorderColorFor(key) {
    var hex = Picker.themeBorderColor(key, root.themePalette)
    if (hex)
      return hex
    var k = Picker.sanitizeBorderColor(key)
    if (k === "red") return Color.urgent
    return Color.accent
  }

  function loadThemePalette(raw) {
    root.themePalette = Picker.parseThemePalette(raw)
  }

  function pipBorderPxFor(key) {
    var k = Picker.sanitizeBorderWidth(key)
    if (k === "off") return 0
    if (k === "thin") return Math.max(2, Style.space(2))
    if (k === "thick") return Math.max(6, Style.space(8))
    return Math.max(3, Style.space(4))
  }

  function setPipBorderColor(key) {
    root.pipBorderColorKey = Picker.sanitizeBorderColor(key)
    root.savePipPrefs()
  }

  function setPipBorderWidth(key) {
    root.pipBorderWidthKey = Picker.sanitizeBorderWidth(key)
    root.savePipPrefs()
  }

  function setPipCornerFrac(value) {
    root.pipCornerFrac = Picker.sanitizeCornerFrac(value)
    root.savePipPrefs()
  }

  function loadPipPrefs(raw) {
    if (root.pipPrefsLoaded)
      return
    try {
      var parsed = JSON.parse(String(raw || "{}"))
      if (parsed && parsed.borderColor)
        root.pipBorderColorKey = Picker.sanitizeBorderColor(parsed.borderColor)
      if (parsed && parsed.borderWidth)
        root.pipBorderWidthKey = Picker.sanitizeBorderWidth(parsed.borderWidth)
      if (parsed && parsed.cameraId)
        root.cameraId = String(parsed.cameraId)
      if (parsed && parsed.cameraName)
        root.cameraName = String(parsed.cameraName)
      if (parsed && parsed.cornerFrac !== undefined && parsed.cornerFrac !== null)
        root.pipCornerFrac = Picker.sanitizeCornerFrac(parsed.cornerFrac)
      if (parsed && parsed.showKeys === true)
        root.showKeys = true
    } catch (e) {
    }
    root.pipPrefsLoaded = true
  }

  function savePipPrefs() {
    if (!root.pipPrefsLoaded || !root.pipPrefsPath)
      return
    pipPrefsFile.setText(JSON.stringify({
      borderColor: root.pipBorderColorKey,
      borderWidth: root.pipBorderWidthKey,
      cornerFrac: root.pipCornerFrac,
      showKeys: root.showKeys,
      cameraId: root.cameraId,
      cameraName: root.cameraName
    }) + "\n")
  }

  function rememberCamera(id, name) {
    var dirty = false
    if (id && root.cameraId !== id) {
      root.cameraId = id
      dirty = true
    }
    if (name && root.cameraName !== name) {
      root.cameraName = name
      dirty = true
    }
    if (dirty)
      root.savePipPrefs()
  }

  function setCamera(id, name) {
    root.cameraId = id || ""
    root.cameraName = name || ""
    root.cameraMenuOpen = false
    root.savePipPrefs()
  }

  function currentCameraLabel() {
    var item = camEngine.item
    if (item && item.cameraModel) {
      var m = item.cameraModel
      for (var i = 0; i < m.count; i++) {
        var row = m.get(i)
        if (row.camId === root.cameraId)
          return row.camName
      }
    }
    return root.cameraName || "Camera"
  }

  function qtKeyName(key) {
    if (key >= Qt.Key_A && key <= Qt.Key_Z)
      return String.fromCharCode(65 + (key - Qt.Key_A))
    if (key >= Qt.Key_0 && key <= Qt.Key_9)
      return String.fromCharCode(48 + (key - Qt.Key_0))
    if (key >= Qt.Key_F1 && key <= Qt.Key_F12)
      return "F" + (key - Qt.Key_F1 + 1)
    if (key === Qt.Key_Escape) return "Esc"
    if (key === Qt.Key_Return || key === Qt.Key_Enter) return "Enter"
    if (key === Qt.Key_Space) return "Space"
    if (key === Qt.Key_Tab) return "Tab"
    if (key === Qt.Key_Backspace) return "Backspace"
    if (key === Qt.Key_Delete) return "Delete"
    if (key === Qt.Key_Insert) return "Insert"
    if (key === Qt.Key_Home) return "Home"
    if (key === Qt.Key_End) return "End"
    if (key === Qt.Key_PageUp) return "PgUp"
    if (key === Qt.Key_PageDown) return "PgDn"
    if (key === Qt.Key_Left) return "Left"
    if (key === Qt.Key_Right) return "Right"
    if (key === Qt.Key_Up) return "Up"
    if (key === Qt.Key_Down) return "Down"
    if (key === Qt.Key_BracketLeft) return "["
    if (key === Qt.Key_BracketRight) return "]"
    if (key === Qt.Key_Print) return "Print"
    if (key === Qt.Key_SysReq) return "Print"
    if (key === Qt.Key_Minus) return "-"
    if (key === Qt.Key_Equal) return "="
    if (key === Qt.Key_Comma) return ","
    if (key === Qt.Key_Period) return "."
    if (key === Qt.Key_Slash) return "/"
    if (key === Qt.Key_Backslash) return "\\"
    if (key === Qt.Key_Semicolon) return ";"
    if (key === Qt.Key_Apostrophe) return "'"
    if (key === Qt.Key_QuoteLeft) return "`"
    if (key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R) return "Super"
    if (key === Qt.Key_Control) return "Ctrl"
    if (key === Qt.Key_Alt) return "Alt"
    if (key === Qt.Key_Shift) return "Shift"
    if (key === Qt.Key_CapsLock) return "Caps"
    return ""
  }

  function noteKey(label) {
    var s = String(label || "").replace(/\n/g, "").trim()
    if (!s || !root.showKeys)
      return
    root.keyHudText = s
    keyHudTimer.restart()
  }

  function noteKeyFromEvent(event) {
    if (!root.showKeys || !event)
      return
    var label = Picker.formatKeyChord(
      (event.modifiers & Qt.MetaModifier) !== 0,
      (event.modifiers & Qt.ControlModifier) !== 0,
      (event.modifiers & Qt.AltModifier) !== 0,
      (event.modifiers & Qt.ShiftModifier) !== 0,
      root.qtKeyName(event.key)
    )
    root.noteKey(label)
  }

  function syncKeyListen() {
    var on = root.showKeys && (root.picking || root.recording)
    if (on)
      Quickshell.execDetached(["bash", "-c", "printf 1 > \"$XDG_RUNTIME_DIR/omarchy-capture-keys.on\""])
    else
      Quickshell.execDetached(["rm", "-f", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-capture-keys.on"])
  }

  function confirmRegion() {
    if (!root.hasRegion)
      return "empty"
    if (root.askWebcamShape) {
      root.pickPhase = "shape"
      root.ghosts = []
      root.pickHandle = ""
      return "shape"
    }
    return root.startCountdown()
  }

  function chooseWebcamShape(shape) {
    root.webcamShape = Picker.sanitizeWebcamShape(shape)
    return root.beginWebcamPlace()
  }

  function resetCamView() {
    root.camRot = 0
    root.camInsetL = 0
    root.camInsetT = 0
    root.camInsetR = 0
    root.camInsetB = 0
  }

  function backToShapePanel() {
    if (root.pickPhase !== "place")
      return "idle"
    root.camDragging = false
    root.camResizing = false
    root.cameraMenuOpen = false
    root.pickPhase = "shape"
    root.ghosts = []
    root.pickHandle = ""
    return "shape"
  }

  function grabPlacement() {
    if (Picker.isSquarePip(root.webcamShape)) {
      var side = Math.min(root.regionW, root.regionH)
      return {
        x: root.regionX + Math.round((root.regionW - side) / 2),
        y: root.regionY + Math.round((root.regionH - side) / 2),
        w: side,
        h: side
      }
    }
    return { x: root.regionX, y: root.regionY, w: root.regionW, h: root.regionH }
  }

  Behavior on camX { enabled: root.camAnimating; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  Behavior on camY { enabled: root.camAnimating; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  Behavior on camW { enabled: root.camAnimating; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  Behavior on camH { enabled: root.camAnimating; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

  function clampCamPos(x, y, w, h) {
    return root.clampCamBox(x, y, w, h, root.camRot)
  }

  function camAABB(x, y, w, h, rotDeg) {
    var rot = (root.webcamShape === "oval" ? rotDeg : 0) * Math.PI / 180
    var c = Math.cos(rot)
    var s = Math.sin(rot)
    var bw = Math.abs(w * c) + Math.abs(h * s)
    var bh = Math.abs(w * s) + Math.abs(h * c)
    var cx = x + w / 2
    var cy = y + h / 2
    return { x: cx - bw / 2, y: cy - bh / 2, w: bw, h: bh, cx: cx, cy: cy }
  }

  function clampCamBox(x, y, w, h, rot) {
    w = Math.max(48, Math.round(w))
    h = Math.max(48, Math.round(h))
    if (Picker.isSquarePip(root.webcamShape)) {
      var side = Math.max(48, Math.round((w + h) / 2))
      w = side
      h = side
    }
    var cx = x + w / 2
    var cy = y + h / 2
    if (!root.hasRegion)
      return { x: Math.round(cx - w / 2), y: Math.round(cy - h / 2), w: w, h: h }
    var rw = root.regionW
    var rh = root.regionH
    var box = root.camAABB(cx - w / 2, cy - h / 2, w, h, rot)
    if (box.w > rw || box.h > rh) {
      var k = Math.min(rw / Math.max(1, box.w), rh / Math.max(1, box.h))
      w = Math.max(48, Math.round(w * k))
      h = Math.max(48, Math.round(h * k))
      if (Picker.isSquarePip(root.webcamShape)) {
        var s2 = Math.min(w, h)
        w = s2
        h = s2
      }
      box = root.camAABB(cx - w / 2, cy - h / 2, w, h, rot)
    }
    if (box.x < root.regionX)
      cx += root.regionX - box.x
    if (box.y < root.regionY)
      cy += root.regionY - box.y
    if (box.x + box.w > root.regionX + rw)
      cx -= (box.x + box.w) - (root.regionX + rw)
    if (box.y + box.h > root.regionY + rh)
      cy -= (box.y + box.h) - (root.regionY + rh)
    return { x: Math.round(cx - w / 2), y: Math.round(cy - h / 2), w: w, h: h }
  }

  function persistCam() {
    Quickshell.execDetached([
      root.pluginDir + "/bin/cam-update",
      String(root.camX), String(root.camY), String(root.camW), String(root.camH),
      String(Math.round(root.camRot))
    ])
  }

  function cropCamFrom(handle, w0, h0, dx, dy, l0, t0, r0, b0) {
    var nx = dx / Math.max(1, w0)
    var ny = dy / Math.max(1, h0)
    var l = l0
    var t = t0
    var r = r0
    var b = b0
    if (handle.indexOf("e") !== -1) r = r0 - nx
    if (handle.indexOf("w") !== -1) l = l0 + nx
    if (handle.indexOf("s") !== -1) b = b0 - ny
    if (handle.indexOf("n") !== -1) t = t0 + ny
    function clampI(v) {
      if (v < 0) return 0
      if (v > 0.4) return 0.4
      return v
    }
    l = clampI(l)
    t = clampI(t)
    r = clampI(r)
    b = clampI(b)
    if (l + r > 0.7) {
      var k = 0.7 / (l + r)
      l *= k
      r *= k
    }
    if (t + b > 0.7) {
      var k2 = 0.7 / (t + b)
      t *= k2
      b *= k2
    }
    root.camInsetL = l
    root.camInsetT = t
    root.camInsetR = r
    root.camInsetB = b
  }

  function setCamRot(deg) {
    var r = deg
    while (r > 180) r -= 360
    while (r < -180) r += 360
    root.camRot = r
    var p = root.clampCamBox(root.camX, root.camY, root.camW, root.camH, r)
    root.camX = p.x
    root.camY = p.y
    root.camW = p.w
    root.camH = p.h
  }

  function finishCamResize() {
    root.camResizing = false
    root.persistCam()
  }

  function dragCam(x, y) {
    root.camAnimating = false
    root.camDidDrag = true
    var p = root.clampCamPos(x, y, root.camW, root.camH)
    if (p.x === root.camX && p.y === root.camY)
      return
    root.camX = p.x
    root.camY = p.y
  }

  function finishCamDrag() {
    root.camDragging = false
    root.camAnimating = true
    if (!root.camDidDrag) {
      root.persistCam()
      return
    }
    root.camDidDrag = false
    var w = root.camW
    var h = root.camH
    var inset = 8
    var corners = [
      { x: root.regionX + inset, y: root.regionY + inset },
      { x: root.regionX + root.regionW - w - inset, y: root.regionY + inset },
      { x: root.regionX + inset, y: root.regionY + root.regionH - h - inset },
      { x: root.regionX + root.regionW - w - inset, y: root.regionY + root.regionH - h - inset }
    ]
    var best = corners[0]
    var bestD = 1e15
    for (var i = 0; i < corners.length; i++) {
      var dx = root.camX - corners[i].x
      var dy = root.camY - corners[i].y
      var d = dx * dx + dy * dy
      if (d < bestD) {
        bestD = d
        best = corners[i]
      }
    }
    var p = root.clampCamPos(best.x, best.y, w, h)
    root.camX = p.x
    root.camY = p.y
    root.persistCam()
  }

  function resizeCam(action) {
    if (root.camW <= 0 || !root.hasRegion)
      return "idle"
    var fillW = root.regionW
    var fillH = root.regionH
    if (Picker.isSquarePip(root.webcamShape)) {
      fillW = Math.min(root.regionW, root.regionH)
      fillH = fillW
    }
    var pct = fillW > 0 ? (root.camW * 100 / fillW) : 100
    var frac = 100
    if (action === "large") frac = 55
    else if (action === "medium") frac = 35
    else if (action === "small") frac = 22
    else if (action === "fill" || action === "reset") {
      frac = 100
      if (action === "reset")
        root.resetCamView()
    } else if (action === "smaller") {
      if (pct > 70) frac = 55
      else if (pct > 45) frac = 35
      else frac = 22
    } else if (action === "larger") {
      if (pct < 28) frac = 35
      else if (pct < 48) frac = 55
      else frac = 100
    }
    var w = Math.max(48, Math.round(fillW * frac / 100))
    var h = Math.max(48, Math.round(fillH * frac / 100))
    var cx = root.camX + root.camW / 2
    var cy = root.camY + root.camH / 2
    var p = root.clampCamPos(cx - w / 2, cy - h / 2, w, h)
    root.camAnimating = true
    root.camX = p.x
    root.camY = p.y
    root.camW = p.w
    root.camH = p.h
    root.persistCam()
    return "ok"
  }

  function beginWebcamPlace() {
    root.pickPhase = "place"
    root.ghosts = []
    root.pickHandle = ""
    root.resetCamView()
    if (!root.camPreviewActive) {
      var p = root.grabPlacement()
      root.camAnimating = false
      root.camX = p.x
      root.camY = p.y
      root.camW = p.w
      root.camH = p.h
      Qt.callLater(function() { root.camAnimating = true })
      var region = root.regionW + "x" + root.regionH + "+" + root.regionX + "+" + root.regionY
      Quickshell.execDetached([
        root.pluginDir + "/bin/start-cam",
        root.webcamShape,
        region,
        root.fadeIn ? "1" : "0",
        root.fadeOut ? "1" : "0"
      ])
      root.camPreviewActive = true
    } else {
      var next = root.grabPlacement()
      var p2 = root.clampCamPos(next.x, next.y, next.w, next.h)
      root.camAnimating = true
      root.camX = p2.x
      root.camY = p2.y
      root.camW = p2.w
      root.camH = p2.h
      root.persistCam()
    }
    return "place"
  }

  function stopWebcamPreview() {
    root.camDragging = false
    root.camResizing = false
    root.cameraMenuOpen = false
    root.camPreviewActive = false
    Quickshell.execDetached([root.pluginDir + "/bin/stop-cam"])
  }

  function startCountdown() {
    if (!root.hasRegion)
      return "empty"
    root.cameraMenuOpen = false
    root.pickPhase = "countdown"
    root.ghosts = []
    root.pickHandle = ""
    root.countdownValue = 3
    countdownTimer.restart()
    return "countdown"
  }

  function finishPick(ok) {
    countdownTimer.stop()
    if (!root.picking)
      return "idle"
    if (ok && !root.hasRegion)
      return "empty"
    var geo = ok ? (root.regionX + "," + root.regionY + " " + root.regionW + "x" + root.regionH) : ""
    var status = ok ? "ok" : "cancel"
    var shape = (ok && root.askWebcamShape) ? root.webcamShape : ""
    if (!ok)
      root.stopWebcamPreview()
    if (root.selectionFile && root.doneFile) {
      Quickshell.execDetached([
        root.pluginDir + "/bin/finish-pick",
        geo,
        root.selectionFile,
        status,
        root.doneFile,
        shape,
        root.fadeIn ? "1" : "0",
        root.fadeOut ? "1" : "0"
      ])
    }
    root.picking = false
    root.pickPhase = "idle"
    root.keyHudText = ""
    root.ghosts = []
    if (ok) {
      root.forced = true
    } else {
      root.forced = false
      root.hasRegion = false
    }
    return status
  }

  function applyGhost(g) {
    if (!g) return
    root.anchorX = root.dirX < 0 ? g.x + g.w : g.x
    root.anchorY = root.dirY < 0 ? g.y + g.h : g.y
    root.setRegion(g.x, g.y, g.w, g.h, g.label)
    root.pickPhase = "adjust"
  }

  function pointerAt(screen, mouseX, mouseY) {
    return { x: Math.round(screen.x + mouseX), y: Math.round(screen.y + mouseY) }
  }

  function onPointerPressed(screen, mouse) {
    root.lockScreen(screen)
    var p = root.pointerAt(screen, mouse.x, mouse.y)
    if (root.cameraMenuOpen && root.pickPhase === "place") {
      root.cameraMenuOpen = false
      if (mouse.button === Qt.RightButton)
        root.backToShapePanel()
      return
    }
    if (mouse.button === Qt.RightButton) {
      if (root.pickPhase === "place")
        root.backToShapePanel()
      else
        root.finishPick(false)
      return
    }
    if (root.pickUiLocked)
      return
    var r = root.hasRegion ? root.currentRect : null
    var handle = r ? Picker.hitHandle(p.x, p.y, r) : ""
    var ghost = Picker.hitGhost(p.x, p.y, root.ghosts)
    if (handle) {
      root.pickPhase = "resize"
      root.pickHandle = handle
      root.pressRect = { x: r.x, y: r.y, w: r.w, h: r.h }
      root.pressX = p.x
      root.pressY = p.y
      return
    }
    if (ghost) {
      root.applyGhost(ghost)
      return
    }
    if (r && Picker.inside(p.x, p.y, r)) {
      root.pickPhase = "move"
      root.pressRect = { x: r.x, y: r.y, w: r.w, h: r.h }
      root.pressX = p.x
      root.pressY = p.y
      return
    }
    root.pickPhase = "drag"
    root.anchorX = p.x
    root.anchorY = p.y
    root.dirX = 1
    root.dirY = 1
    root.hasRegion = false
    root.snappedLabel = ""
    root.refreshGhosts()
  }

  function onPointerMoved(screen, mouse) {
    var p = root.pointerAt(screen, mouse.x, mouse.y)
    var shift = (mouse.modifiers & Qt.ShiftModifier) !== 0
    if (root.pickPhase === "drag") {
      var raw = Picker.rectFromPoints(root.anchorX, root.anchorY, p.x, p.y)
      root.dirX = raw.dirX
      root.dirY = raw.dirY
      var list = Picker.ghosts(root.anchorX, root.anchorY, root.dirX, root.dirY, root.pickSX, root.pickSY, root.pickSW, root.pickSH)
      var snapped = shift ? { x: raw.x, y: raw.y, w: raw.w, h: raw.h, snapped: "" } : Picker.snapToGhosts(raw, list)
      root.setRegion(snapped.x, snapped.y, snapped.w, snapped.h, snapped.snapped)
      return
    }
    if (root.pickPhase === "resize") {
      var resized = Picker.resize(root.pressRect, root.pickHandle, p.x, p.y)
      root.dirX = root.pickHandle.indexOf("w") !== -1 ? -1 : 1
      root.dirY = root.pickHandle.indexOf("n") !== -1 ? -1 : 1
      if (root.dirX < 0) root.anchorX = root.pressRect.x + root.pressRect.w
      else root.anchorX = root.pressRect.x
      if (root.dirY < 0) root.anchorY = root.pressRect.y + root.pressRect.h
      else root.anchorY = root.pressRect.y
      var resizeGhosts = Picker.ghosts(root.anchorX, root.anchorY, root.dirX, root.dirY, root.pickSX, root.pickSY, root.pickSW, root.pickSH)
      var resizeSnap = shift ? resized : Picker.snapToGhosts(resized, resizeGhosts)
      root.setRegion(resizeSnap.x, resizeSnap.y, resizeSnap.w, resizeSnap.h, resizeSnap.snapped || "")
      return
    }
    if (root.pickPhase === "move") {
      var moved = Picker.move(root.pressRect, p.x - root.pressX, p.y - root.pressY)
      root.anchorX = moved.x
      root.anchorY = moved.y
      root.dirX = 1
      root.dirY = 1
      root.setRegion(moved.x, moved.y, moved.w, moved.h, root.snappedLabel)
      return
    }
    var hoverR = root.hasRegion ? root.currentRect : null
    root.hoverHandle = hoverR ? Picker.hitHandle(p.x, p.y, hoverR) : ""
    var hg = Picker.hitGhost(p.x, p.y, root.ghosts)
    root.hoverGhost = hg ? hg.label : ""
  }

  function onPointerReleased(mouse) {
    if (mouse.button === Qt.RightButton)
      return
    if (root.pickUiLocked)
      return
    if (root.pickPhase === "drag" && root.hasRegion && root.regionW * root.regionH < 20) {
      root.hasRegion = false
      root.pickPhase = "idle"
      return
    }
    if (root.hasRegion)
      root.pickPhase = "adjust"
    else
      root.pickPhase = "idle"
    root.pickHandle = ""
  }

  function onPointerDoubleClicked() {
    if (root.pickUiLocked)
      return
    if (root.hasRegion)
      root.confirmRegion()
  }

  function handleKeys(event) {
    root.noteKeyFromEvent(event)
    if (event.key === Qt.Key_Escape) {
      if (root.cameraMenuOpen)
        root.cameraMenuOpen = false
      else if (root.pickPhase === "place")
        root.backToShapePanel()
      else
        root.finishPick(false)
      event.accepted = true
      return
    }
    if (root.pickPhase === "countdown") {
      event.accepted = true
      return
    }
    if (root.pickPhase === "place") {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
        root.startCountdown()
      else
        return
      event.accepted = true
      return
    }
    if (root.pickPhase === "shape") {
      if (event.key === Qt.Key_Left)
        root.webcamShape = Picker.cycleWebcamShape(root.webcamShape, -1)
      else if (event.key === Qt.Key_Right)
        root.webcamShape = Picker.cycleWebcamShape(root.webcamShape, 1)
      else if (event.key === Qt.Key_R)
        root.webcamShape = "rectangle"
      else if (event.key === Qt.Key_S)
        root.webcamShape = "square"
      else if (event.key === Qt.Key_C)
        root.webcamShape = "circle"
      else if (event.key === Qt.Key_O)
        root.webcamShape = "oval"
      else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
        root.chooseWebcamShape(root.webcamShape)
      else
        return
      event.accepted = true
      return
    }
    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && root.hasRegion) {
      root.confirmRegion()
      event.accepted = true
      return
    }
    if (!root.hasRegion)
      return
    var step = (event.modifiers & Qt.ShiftModifier) ? 10 : 1
    var dx = 0
    var dy = 0
    if (event.key === Qt.Key_Left) dx = -step
    else if (event.key === Qt.Key_Right) dx = step
    else if (event.key === Qt.Key_Up) dy = -step
    else if (event.key === Qt.Key_Down) dy = step
    else return
    root.anchorX = root.regionX + dx
    root.anchorY = root.regionY + dy
    root.setRegion(root.regionX + dx, root.regionY + dy, root.regionW, root.regionH, root.snappedLabel)
    event.accepted = true
  }

  function cursorShapeFor(handle, ghost) {
    var which = Picker.cursorForHandle(handle)
    if (which === "ns") return Qt.SizeVerCursor
    if (which === "ew") return Qt.SizeHorCursor
    if (which === "nesw") return Qt.SizeBDiagCursor
    if (which === "nwse") return Qt.SizeFDiagCursor
    if (root.pickPhase === "move") return Qt.SizeAllCursor
    if (ghost) return Qt.PointingHandCursor
    if (root.hasRegion && root.pickPhase === "adjust") return Qt.CrossCursor
    return Qt.CrossCursor
  }

  function refresh() {
    if (statusProc.running) return
    statusProc.command = ["bash", root.statusScript]
    statusProc.running = true
  }

  function screenIntersects(screen) {
    if (!root.hasRegion || !screen) return false
    return root.regionX < screen.x + screen.width
      && root.regionX + root.regionW > screen.x
      && root.regionY < screen.y + screen.height
      && root.regionY + root.regionH > screen.y
  }

  onShowKeysChanged: root.syncKeyListen()
  onPickingChanged: root.syncKeyListen()
  onRecordingChanged: root.syncKeyListen()
  Component.onCompleted: {
    root.syncKeyListen()
    root.refresh()
  }

  Timer {
    interval: 400
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: keyHudTimer
    interval: 1400
    repeat: false
    onTriggered: root.keyHudText = ""
  }

  Timer {
    id: countdownTimer
    interval: 1000
    repeat: true
    onTriggered: {
      if (root.countdownValue > 1) {
        root.countdownValue -= 1
      } else {
        stop()
        root.finishPick(true)
      }
    }
  }

  FileView {
    path: "/tmp/omarchy-screenrecord-filename"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
    onLoaded: root.refresh()
    onLoadFailed: root.refresh()
  }

  FileView {
    id: pipPrefsFile
    path: root.pipPrefsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadPipPrefs(text())
    onLoadFailed: root.loadPipPrefs("")
  }

  FileView {
    path: root.keyHudPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.noteKey(text())
  }

  FileView {
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadThemePalette(text())
    onFileChanged: reload()
    onLoadFailed: root.loadThemePalette("")
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  IpcHandler {
    target: "capture-overlay"
    function show(payloadJson: string): string { return root.showForced(payloadJson) }
    function hide(): string { return root.hideForced() }
    function pick(payloadJson: string): string { return root.startPick(payloadJson) }
    function cancel(): string { return root.finishPick(false) }
    function confirm(): string {
      if (root.pickPhase === "place") return root.startCountdown()
      if (root.pickPhase === "shape") return root.chooseWebcamShape(root.webcamShape)
      return root.confirmRegion()
    }
    function resizeCam(action: string): string { return root.resizeCam(action) }
    function key(label: string): string { root.noteKey(label); return "ok" }
    function state(): string {
      return JSON.stringify({
        recording: root.recording,
        picking: root.picking,
        camPreview: root.camPreviewActive,
        phase: root.pickPhase,
        forced: root.forced,
        hasRegion: root.hasRegion,
        x: root.regionX,
        y: root.regionY,
        w: root.regionW,
        h: root.regionH,
        snapped: root.snappedLabel
      })
    }
  }

  component FrameRect: Rectangle {
    color: root.frameColor
  }

  component KeyHud: Item {
    required property int sx
    required property int sy
    visible: root.showKeys && root.keyHudText !== "" && root.hasRegion && (root.recording || root.picking)
    z: 90
    width: hudBox.width
    height: hudBox.height
    x: root.regionX - sx + Math.max(Style.space(8), Math.round((root.regionW - width) / 2))
    y: root.regionY - sy + root.regionH - height - Style.space(16)

    BorderSurface {
      id: hudBox
      color: Util.alpha(Color.background, 0.92)
      borderSpec: Border.surfaceSpec("popups", "border", Color.accent, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius
      width: hudLabel.implicitWidth + Style.space(28)
      height: Math.max(Style.space(36), hudLabel.implicitHeight + Style.space(14))

      Text {
        id: hudLabel
        anchors.centerIn: parent
        text: root.keyHudText
        textFormat: Text.PlainText
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }
  }

  component CaptureFrame: Item {
    id: frame
    required property int localX
    required property int localY
    required property int localW
    required property int localH
    required property bool showHandles

    Rectangle {
      x: frame.localX - root.framePad
      y: frame.localY - root.framePad
      width: frame.localW + root.framePad * 2
      height: root.contrastWidth
      color: root.contrastColor
    }
    Rectangle {
      x: frame.localX - root.framePad
      y: frame.localY + frame.localH + root.framePad - root.contrastWidth
      width: frame.localW + root.framePad * 2
      height: root.contrastWidth
      color: root.contrastColor
    }
    Rectangle {
      x: frame.localX - root.framePad
      y: frame.localY - root.framePad
      width: root.contrastWidth
      height: frame.localH + root.framePad * 2
      color: root.contrastColor
    }
    Rectangle {
      x: frame.localX + frame.localW + root.framePad - root.contrastWidth
      y: frame.localY - root.framePad
      width: root.contrastWidth
      height: frame.localH + root.framePad * 2
      color: root.contrastColor
    }

    Rectangle {
      x: frame.localX - root.borderWidth
      y: frame.localY - root.borderWidth
      width: frame.localW + root.borderWidth * 2
      height: root.borderWidth
      color: root.frameColor
    }
    Rectangle {
      x: frame.localX - root.borderWidth
      y: frame.localY + frame.localH
      width: frame.localW + root.borderWidth * 2
      height: root.borderWidth
      color: root.frameColor
    }
    Rectangle {
      x: frame.localX - root.borderWidth
      y: frame.localY
      width: root.borderWidth
      height: frame.localH
      color: root.frameColor
    }
    Rectangle {
      x: frame.localX + frame.localW
      y: frame.localY
      width: root.borderWidth
      height: frame.localH
      color: root.frameColor
    }

    Repeater {
      model: 4
      Item {
        required property int index
        readonly property bool leftSide: index === 0 || index === 2
        readonly property bool topSide: index === 0 || index === 1
        FrameRect {
          x: leftSide ? frame.localX - root.framePad : frame.localX + frame.localW + root.framePad - root.cornerLength
          y: topSide ? frame.localY - root.framePad : frame.localY + frame.localH
          width: root.cornerLength
          height: root.framePad
        }
        FrameRect {
          x: leftSide ? frame.localX - root.framePad : frame.localX + frame.localW
          y: topSide ? frame.localY - root.framePad : frame.localY + frame.localH + root.framePad - root.cornerLength
          width: root.framePad
          height: root.cornerLength
        }
      }
    }

    Repeater {
      model: frame.showHandles ? 4 : 0
      Rectangle {
        required property int index
        readonly property bool leftSide: index === 0 || index === 2
        readonly property bool topSide: index === 0 || index === 1
        width: Style.space(10)
        height: Style.space(10)
        radius: 1
        color: root.frameColor
        border.color: root.contrastColor
        border.width: 1
        x: (leftSide ? frame.localX : frame.localX + frame.localW) - width / 2
        y: (topSide ? frame.localY : frame.localY + frame.localH) - height / 2
      }
    }
  }

  component PipDragHandle: Item {
    id: pipChrome
    required property int sx
    required property int sy
    readonly property bool showHandles: root.pickPhase === "place"
    readonly property int handlePad: showHandles ? Style.space(14) : 0
    readonly property int rotPad: showHandles && root.webcamShape === "oval" ? Style.space(32) : 0
    readonly property int camCount: camEngine.item ? camEngine.item.cameraCount : 0
    readonly property bool showCamPick: showHandles && camCount > 1
    readonly property int camPickH: showCamPick ? Style.space(34) : 0
    readonly property int camRowH: Style.space(30)
    readonly property int camMenuH: showCamPick && root.cameraMenuOpen ? camCount * camRowH + Style.space(8) : 0
    readonly property int camPickGap: showCamPick ? Style.space(8) : 0
    readonly property int camPickBlock: camPickH + camMenuH + camPickGap
    readonly property bool camPickBelow: {
      if (!showCamPick)
        return true
      var pipBottom = Math.round(root.camY + root.camH / 2 + boxH / 2)
      return pipBottom + camPickBlock + 8 <= root.pickSY + root.pickSH
    }
    readonly property int topExtra: rotPad + (camPickBelow ? 0 : camPickBlock)
    readonly property int botExtra: camPickBelow ? camPickBlock : 0
    readonly property real rotRad: (root.webcamShape === "oval" ? root.camRot : 0) * Math.PI / 180
    readonly property int boxW: Math.max(1, Math.ceil(Math.abs(root.camW * Math.cos(rotRad)) + Math.abs(root.camH * Math.sin(rotRad))))
    readonly property int boxH: Math.max(1, Math.ceil(Math.abs(root.camW * Math.sin(rotRad)) + Math.abs(root.camH * Math.cos(rotRad))))
    readonly property int chromeW: Math.max(boxW + handlePad * 2, showCamPick ? Style.space(248) : 0)
    visible: root.camPreviewActive && root.camW > 0 && root.pickPhase !== "shape"
    x: Math.round(root.camX + root.camW / 2 - chromeW / 2) - sx
    y: Math.round(root.camY + root.camH / 2 - boxH / 2) - handlePad - topExtra - sy
    width: chromeW
    height: boxH + handlePad * 2 + topExtra + botExtra

    Item {
      id: pipBody
      width: Math.max(1, root.camW)
      height: Math.max(1, root.camH)
      x: (pipChrome.chromeW - width) / 2
      y: handlePad + pipChrome.topExtra + (pipChrome.boxH - height) / 2
      rotation: root.webcamShape === "oval" ? root.camRot : 0
      transformOrigin: Item.Center

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: pressed || root.camDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real grabX: 0
        property real grabY: 0
        onPressed: function(mouse) {
          var g = mapToItem(pipChrome, mouse.x, mouse.y)
          grabX = g.x
          grabY = g.y
          root.cameraMenuOpen = false
          root.camAnimating = false
          root.camDragging = true
        }
        onPositionChanged: function(mouse) {
          if (!pressed)
            return
          var g = mapToItem(pipChrome, mouse.x, mouse.y)
          root.dragCam(root.camX + g.x - grabX, root.camY + g.y - grabY)
        }
        onReleased: root.finishCamDrag()
        onCanceled: root.finishCamDrag()
      }

      Repeater {
        model: pipChrome.showHandles ? ["nw", "n", "ne", "e", "se", "s", "sw", "w"] : []
        Rectangle {
          required property string modelData
          readonly property string handle: modelData
          readonly property int hs: Style.space(12)
          width: hs
          height: hs
          radius: 2
          z: 30
          color: Color.accent
          border.color: Color.background
          border.width: 1
          x: handle.indexOf("w") !== -1 ? -hs / 2 : (handle.indexOf("e") !== -1 ? parent.width - hs / 2 : (parent.width - hs) / 2)
          y: handle.indexOf("n") !== -1 ? -hs / 2 : (handle.indexOf("s") !== -1 ? parent.height - hs / 2 : (parent.height - hs) / 2)
          MouseArea {
            anchors.fill: parent
            preventStealing: true
            cursorShape: {
              if (Picker.isSquarePip(root.webcamShape))
                return Qt.SizeAllCursor
              if (handle === "n" || handle === "s")
                return Qt.SizeVerCursor
              if (handle === "e" || handle === "w")
                return Qt.SizeHorCursor
              if (handle === "nw" || handle === "se")
                return Qt.SizeFDiagCursor
              return Qt.SizeBDiagCursor
            }
            property real sX: 0
            property real sY: 0
            property int sCamW: 0
            property int sCamH: 0
            property real sL: 0
            property real sT: 0
            property real sR: 0
            property real sB: 0
            onPressed: function(mouse) {
              var p = mapToItem(pipBody, mouse.x, mouse.y)
              sX = p.x
              sY = p.y
              sCamW = root.camW
              sCamH = root.camH
              sL = root.camInsetL
              sT = root.camInsetT
              sR = root.camInsetR
              sB = root.camInsetB
              root.cameraMenuOpen = false
              root.camAnimating = false
              root.camResizing = true
            }
            onPositionChanged: function(mouse) {
              if (!pressed)
                return
              var p = mapToItem(pipBody, mouse.x, mouse.y)
              root.cropCamFrom(handle, sCamW, sCamH, p.x - sX, p.y - sY, sL, sT, sR, sB)
            }
            onReleased: root.finishCamResize()
            onCanceled: root.finishCamResize()
          }
        }
      }

      Item {
        visible: pipChrome.showHandles && root.webcamShape === "oval"
        width: Style.space(16)
        height: Style.space(28)
        x: (parent.width - width) / 2
        y: -height - 2
        z: 31
        Rectangle {
          width: 2
          height: parent.height - Style.space(12)
          anchors.horizontalCenter: parent.horizontalCenter
          color: Color.accent
        }
        Rectangle {
          width: Style.space(12)
          height: Style.space(12)
          radius: width / 2
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          color: Color.accent
          border.color: Color.background
          border.width: 1
        }
        MouseArea {
          anchors.fill: parent
          preventStealing: true
          cursorShape: Qt.CrossCursor
          property real startAng: 0
          property real startRot: 0
          onPressed: function(mouse) {
            var p = mapToItem(pipChrome, mouse.x, mouse.y)
            var cx = pipBody.x + pipBody.width / 2
            var cy = pipBody.y + pipBody.height / 2
            startAng = Math.atan2(p.y - cy, p.x - cx)
            startRot = root.camRot
            root.cameraMenuOpen = false
            root.camAnimating = false
            root.camResizing = true
          }
          onPositionChanged: function(mouse) {
            if (!pressed)
              return
            var p = mapToItem(pipChrome, mouse.x, mouse.y)
            var cx = pipBody.x + pipBody.width / 2
            var cy = pipBody.y + pipBody.height / 2
            var ang = Math.atan2(p.y - cy, p.x - cx)
            root.setCamRot(startRot + (ang - startAng) * 180 / Math.PI)
          }
          onReleased: root.finishCamResize()
          onCanceled: root.finishCamResize()
        }
      }
    }

    Item {
      id: camPick
      visible: pipChrome.showCamPick
      z: 40
      width: Math.max(Style.space(200), Math.min(parent.width - Style.space(8), Style.space(280)))
      height: pipChrome.camPickH + pipChrome.camMenuH
      x: (parent.width - width) / 2
      y: pipChrome.camPickBelow
        ? pipBody.y + pipBody.height + pipChrome.camPickGap
        : pipChrome.handlePad
      onVisibleChanged: if (!visible) root.cameraMenuOpen = false

      BorderSurface {
        id: camPickTrigger
        width: parent.width
        height: pipChrome.camPickH
        radius: Style.cornerRadius
        color: Util.alpha(Color.background, 0.94)
        borderSpec: Border.surfaceSpec("popups", "border", root.cameraMenuOpen ? Color.accent : Color.popups.border, Math.max(1, Style.space(root.cameraMenuOpen ? 3 : 2)))

        Text {
          anchors.left: parent.left
          anchors.right: camPickChevron.left
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(8)
          text: root.currentCameraLabel()
          textFormat: Text.PlainText
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          id: camPickChevron
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.rightMargin: Style.space(10)
          text: root.cameraMenuOpen ? "▴" : "▾"
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
        MouseArea {
          anchors.fill: parent
          preventStealing: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.cameraMenuOpen = !root.cameraMenuOpen
        }
      }

      Column {
        visible: root.cameraMenuOpen
        y: pipChrome.camPickH + Style.space(4)
        width: parent.width
        spacing: 0

        Repeater {
          model: camEngine.item ? camEngine.item.cameraModel : 0
          Rectangle {
            required property string camId
            required property string camName
            required property string camDesc
            width: camPick.width
            height: pipChrome.camRowH
            color: camId === root.cameraId ? Util.alpha(Color.accent, 0.22) : Util.alpha(Color.background, 0.94)
            border.color: Color.popups.border
            border.width: 1

            Text {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              text: camName
              textFormat: Text.PlainText
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: camId === root.cameraId
              elide: Text.ElideRight
              verticalAlignment: Text.AlignVCenter
            }
            MouseArea {
              anchors.fill: parent
              preventStealing: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setCamera(camId, camDesc)
            }
          }
        }
      }
    }
  }

  component PipBorderSwatch: Item {
    required property string colorKey
    width: Style.space(26)
    height: Style.space(26)
    readonly property bool selected: root.pipBorderColorKey === colorKey

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: "transparent"
      border.color: selected ? Color.popups.text : "transparent"
      border.width: 2
    }
    Rectangle {
      anchors.centerIn: parent
      width: Style.space(18)
      height: Style.space(18)
      radius: width / 2
      color: root.pipBorderColorFor(colorKey)
      border.color: Color.popups.border
      border.width: 1
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.setPipBorderColor(colorKey)
    }
  }

  component FadeCheck: Item {
    required property string label
    required property bool checked
    signal toggled()
    width: fadeRow.implicitWidth
    height: fadeRow.implicitHeight
    Row {
      id: fadeRow
      spacing: Style.space(8)
      Rectangle {
        width: Style.space(18)
        height: Style.space(18)
        radius: 3
        anchors.verticalCenter: parent.verticalCenter
        color: checked ? Color.accent : "transparent"
        border.color: Color.accent
        border.width: 2
        Text {
          anchors.centerIn: parent
          visible: checked
          text: "✓"
          color: Color.background
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
      Text {
        text: label
        textFormat: Text.PlainText
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: toggled()
    }
  }

  component ShapeCard: Item {
    required property string shapeKey
    required property string label
    property int previewW: Style.space(52)
    property int previewH: Style.space(36)
    property real previewRadius: 2
    width: Style.space(148)
    height: Style.space(148)
    BorderSurface {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Util.alpha(Color.background, 0.94)
      borderSpec: Border.surfaceSpec("popups", "border", root.webcamShape === shapeKey ? Color.accent : Color.popups.border, Math.max(1, Style.space(root.webcamShape === shapeKey ? 3 : 2)))
      Column {
        anchors.fill: parent
        anchors.margins: Style.space(14)
        spacing: Style.space(10)
        Item {
          width: parent.width
          height: Style.space(72)
          Rectangle {
            anchors.centerIn: parent
            width: previewW
            height: previewH
            radius: previewRadius
            color: Util.alpha(root.pipBorderColor, 0.35)
            border.color: root.pipBorderColor
            border.width: root.pipBorderPreview
          }
        }
        Text {
          width: parent.width
          text: label
          textFormat: Text.PlainText
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chooseWebcamShape(shapeKey)
      }
    }
  }

  component PipWidthChip: Item {
    required property string widthKey
    readonly property bool selected: root.pipBorderWidthKey === widthKey
    width: chipLabel.implicitWidth + Style.space(16)
    height: Style.space(26)

    Rectangle {
      anchors.fill: parent
      radius: Math.max(2, Style.cornerRadius)
      color: "transparent"
      border.color: selected ? Color.accent : Color.popups.border
      border.width: selected ? 2 : 1
    }
    Text {
      id: chipLabel
      anchors.centerIn: parent
      text: Picker.borderWidthLabel(widthKey)
      textFormat: Text.PlainText
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: selected
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.setPipBorderWidth(widthKey)
    }
  }

  component CornerSlider: Item {
    width: Style.space(220)
    height: Style.space(28)
    readonly property real maxFrac: 0.5
    readonly property int thumbSize: Style.space(16)

    Rectangle {
      id: cornerTrack
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: Style.space(6)
      radius: height / 2
      color: Util.alpha(Color.popups.border, 0.55)
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(cornerTrack.height, (root.pipCornerFrac / maxFrac) * cornerTrack.width)
      height: cornerTrack.height
      radius: height / 2
      color: Color.accent
    }
    Rectangle {
      id: cornerThumb
      width: thumbSize
      height: thumbSize
      radius: width / 2
      color: Color.accent
      border.color: Color.background
      border.width: 1
      anchors.verticalCenter: parent.verticalCenter
      x: Math.round((root.pipCornerFrac / maxFrac) * (parent.width - width))
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      function setFrom(mx) {
        var t = (mx - thumbSize / 2) / Math.max(1, parent.width - thumbSize)
        if (t < 0) t = 0
        if (t > 1) t = 1
        if (t < 0.03) t = 0
        root.setPipCornerFrac(t * maxFrac)
      }
      onPressed: function(mouse) { setFrom(mouse.x) }
      onPositionChanged: function(mouse) { if (pressed) setFrom(mouse.x) }
    }
  }

  // Live recording frame: click-through except on the pip.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: live
      required property var modelData
      screen: modelData
      visible: !root.picking && root.hasRegion && root.screenIntersects(modelData)
      color: "transparent"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "ianm-capture-live"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      // While dragging, freeze input to the full overlay. A pip-sized mask
      // chases the cursor, so a fast move leaves the region and Hyprland
      // drops the grab — the pip then snaps back to the corner it left.
      mask: (root.camDragging || root.camResizing) ? liveDragHit : (livePip.visible ? livePipHit : livePass)

      Region { id: livePass }
      Region { id: livePipHit; item: livePip }
      Region { id: liveDragHit; item: liveFill }
      Item { id: liveFill; anchors.fill: parent }

      readonly property int sx: modelData.x
      readonly property int sy: modelData.y
      readonly property int localX: root.regionX - sx
      readonly property int localY: root.regionY - sy
      readonly property int holeX: Math.max(0, localX)
      readonly property int holeY: Math.max(0, localY)
      readonly property int holeW: Math.max(0, Math.min(width, localX + root.regionW) - holeX)
      readonly property int holeH: Math.max(0, Math.min(height, localY + root.regionH) - holeY)
      readonly property int chipH: Math.max(Style.space(22), Style.font.caption + Style.space(10))
      readonly property bool chipAbove: localY - root.framePad - chipH - Style.space(6) >= 0
      readonly property int chipY: chipAbove
        ? localY - root.framePad - chipH - Style.space(6)
        : localY + root.regionH + root.framePad + Style.space(6)
      readonly property int chipX: Math.max(Style.space(8), Math.min(localX, width - Style.space(160)))

      PipDragHandle {
        id: livePip
        sx: live.sx
        sy: live.sy
        z: 50
      }

      Rectangle { x: 0; y: 0; width: live.width; height: live.holeY; color: root.dimColor }
      Rectangle {
        x: 0
        y: live.holeY + live.holeH
        width: live.width
        height: Math.max(0, live.height - live.holeY - live.holeH)
        color: root.dimColor
      }
      Rectangle {
        visible: live.holeX > 0 && live.holeH > 0
        x: 0
        y: live.holeY
        width: live.holeX
        height: live.holeH
        color: root.dimColor
      }
      Rectangle {
        visible: live.holeH > 0
        x: live.holeX + live.holeW
        y: live.holeY
        width: Math.max(0, live.width - live.holeX - live.holeW)
        height: live.holeH
        color: root.dimColor
      }

      CaptureFrame {
        anchors.fill: parent
        localX: live.localX
        localY: live.localY
        localW: root.regionW
        localH: root.regionH
        showHandles: false
      }

      KeyHud {
        sx: live.sx
        sy: live.sy
      }

      BorderSurface {
        x: live.chipX
        y: live.chipY
        height: live.chipH
        color: Util.alpha(Color.background, 0.92)
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
        radius: Style.cornerRadius
        width: liveChipRow.width + Style.space(20)

        Row {
          id: liveChipRow
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          spacing: Style.space(8)
          Rectangle {
            width: Style.space(8)
            height: Style.space(8)
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Color.urgent
          }
          Text {
            text: root.askWebcamShape
              ? "REC  " + root.sizeLabel + "  ·  drag camera  ·  Super+Alt+[ ] size"
              : "REC  " + root.sizeLabel
            textFormat: Text.PlainText
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }

  // Interactive picker with snap guides and draggable edges.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: picker
      required property var modelData
      screen: modelData
      visible: root.picking
      color: "transparent"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "ianm-capture-overlay"
      WlrLayershell.layer: WlrLayer.Overlay
      readonly property bool grabKeys: {
        if (!root.picking) return false
        if (root.pickScreenName) return modelData.name === root.pickScreenName
        var focused = Hyprland.focusedMonitor
        if (focused && focused.name) return modelData.name === focused.name
        return true
      }
      WlrLayershell.keyboardFocus: picker.grabKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      // The camera layer is visual-only (empty mask). This overlay keeps the
      // exclusive keyboard grab so Enter/Esc still work while the pip is dragged.
      // Freeze to the full overlay during a pip drag so the grab cannot slip.
      mask: !root.picking
        ? passClicks
        : ((root.pickPhase === "place" || root.pickPhase === "countdown")
          ? ((root.camDragging || root.camResizing || root.cameraMenuOpen) ? fullInput : (pickPip.visible ? pickPipHit : passClicks))
          : fullInput)

      Region { id: passClicks }
      Region { id: fullInput; item: pickArea }
      Region { id: pickPipHit; item: pickPip }

      readonly property int sx: modelData.x
      readonly property int sy: modelData.y
      readonly property bool onPickScreen: !root.pickScreenName || modelData.name === root.pickScreenName
      readonly property int localX: root.regionX - sx
      readonly property int localY: root.regionY - sy
      readonly property int holeX: Math.max(0, localX)
      readonly property int holeY: Math.max(0, localY)
      readonly property int holeW: Math.max(0, Math.min(width, localX + root.regionW) - holeX)
      readonly property int holeH: Math.max(0, Math.min(height, localY + root.regionH) - holeY)
      readonly property int chipH: Math.max(Style.space(24), Style.font.caption + Style.space(12))
      readonly property bool chipAbove: localY - root.framePad - chipH - Style.space(8) >= 0
      readonly property int chipY: chipAbove
        ? localY - root.framePad - chipH - Style.space(8)
        : localY + root.regionH + root.framePad + Style.space(8)
      readonly property int chipX: Math.max(Style.space(8), Math.min(localX, width - Style.space(220)))

      PipDragHandle {
        id: pickPip
        sx: picker.sx
        sy: picker.sy
        z: 50
      }

      MouseArea {
        id: pickArea
        anchors.fill: parent
        hoverEnabled: !root.pickUiLocked
        acceptedButtons: root.pickUiLocked
          ? ((root.cameraMenuOpen ? Qt.LeftButton : Qt.NoButton) | Qt.RightButton)
          : (Qt.LeftButton | Qt.RightButton)
        focus: picker.grabKeys
        cursorShape: root.cursorShapeFor(root.pickPhase === "resize" ? root.pickHandle : root.hoverHandle, root.hoverGhost)
        onPressed: function(mouse) { root.onPointerPressed(picker.modelData, mouse) }
        onPositionChanged: function(mouse) { root.onPointerMoved(picker.modelData, mouse) }
        onReleased: function(mouse) { root.onPointerReleased(mouse) }
        onDoubleClicked: root.onPointerDoubleClicked()
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { root.handleKeys(event) }
        onFocusChanged: if (picker.grabKeys && !focus) Qt.callLater(function() { if (picker.grabKeys) pickArea.forceActiveFocus() })
      }

      Rectangle { x: 0; y: 0; width: picker.width; height: root.hasRegion && picker.onPickScreen ? picker.holeY : picker.height; color: root.scrimColor }
      Rectangle {
        visible: root.hasRegion && picker.onPickScreen
        x: 0
        y: picker.holeY + picker.holeH
        width: picker.width
        height: Math.max(0, picker.height - picker.holeY - picker.holeH)
        color: root.scrimColor
      }
      Rectangle {
        visible: root.hasRegion && picker.onPickScreen && picker.holeX > 0 && picker.holeH > 0
        x: 0
        y: picker.holeY
        width: picker.holeX
        height: picker.holeH
        color: root.scrimColor
      }
      Rectangle {
        visible: root.hasRegion && picker.onPickScreen && picker.holeH > 0
        x: picker.holeX + picker.holeW
        y: picker.holeY
        width: Math.max(0, picker.width - picker.holeX - picker.holeW)
        height: picker.holeH
        color: root.scrimColor
      }
      Rectangle {
        visible: root.hasRegion && picker.onPickScreen
        x: picker.holeX
        y: picker.holeY
        width: picker.holeW
        height: picker.holeH
        color: Util.alpha(Color.background, 0.5)
        opacity: root.scrimAmount
      }

      Repeater {
        model: picker.onPickScreen ? root.ghosts : []
        Rectangle {
          required property var modelData
          x: modelData.x - picker.sx
          y: modelData.y - picker.sy
          width: modelData.w
          height: modelData.h
          color: "transparent"
          border.width: root.hoverGhost === modelData.label ? 3 : 2
          border.color: Util.alpha(root.frameColor, root.hoverGhost === modelData.label ? 0.95 : 0.42)
          radius: 0

          Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Style.space(6)
            anchors.topMargin: -Math.round(Style.font.caption * 1.4)
            text: modelData.label + "  " + modelData.w + " × " + modelData.h
            textFormat: Text.PlainText
            color: Util.alpha(root.frameColor, root.hoverGhost === modelData.label ? 1 : 0.75)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            style: Text.Outline
            styleColor: Util.alpha(Color.background, 0.8)
          }
        }
      }

      CaptureFrame {
        visible: root.hasRegion && picker.onPickScreen
        anchors.fill: parent
        localX: picker.localX
        localY: picker.localY
        localW: root.regionW
        localH: root.regionH
        showHandles: root.pickPhase === "adjust" || root.pickPhase === "resize" || root.pickPhase === "move"
      }

      KeyHud {
        visible: picker.onPickScreen && root.showKeys && root.keyHudText !== "" && root.hasRegion
        sx: picker.sx
        sy: picker.sy
      }

      Item {
        visible: root.pickPhase === "countdown" && picker.onPickScreen && root.hasRegion && !root.camPreviewActive
        x: picker.localX
        y: picker.localY
        width: root.regionW
        height: root.regionH

        Rectangle {
          id: countBadge
          anchors.centerIn: parent
          width: Math.max(Style.space(120), Math.min(Style.space(200), Math.min(parent.width, parent.height) * 0.45))
          height: width
          radius: width / 2
          color: Util.alpha(Color.background, 0.9)
          border.color: Color.accent
          border.width: Math.max(3, Style.space(4))

          Text {
            anchors.centerIn: parent
            text: String(root.countdownValue)
            textFormat: Text.PlainText
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Math.round(countBadge.width * 0.52)
            font.bold: true
          }
        }
      }

      BorderSurface {
        visible: picker.onPickScreen
        x: root.hasRegion ? picker.chipX : Style.space(16)
        y: root.hasRegion ? picker.chipY : picker.height - picker.chipH - Style.space(24)
        height: picker.chipH
        color: Util.alpha(Color.background, 0.92)
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
        radius: Style.cornerRadius
        width: pickerChipRow.width + Style.space(20)

        Row {
          id: pickerChipRow
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          spacing: Style.space(8)
          Rectangle {
            visible: root.hasRegion
            width: Style.space(8)
            height: Style.space(8)
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Color.accent
          }
          Text {
            text: {
              if (root.pickPhase === "countdown")
                return "Recording starts in " + root.countdownValue + " · Esc to cancel"
              if (root.pickPhase === "place")
                return "Drag · crop · camera · Super+Alt+[ ] size · oval rotates · Enter · Esc to go back"
              if (root.pickPhase === "shape")
                return "Click a shape to continue · Esc to cancel"
              if (root.hasRegion)
                return root.sizeLabel + "   Enter · arrows move · drag edges or click a size guide"
              return "Drag a region · snap guides 1080p / 720p / 900p · arrows move · Esc"
            }
            textFormat: Text.PlainText
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      Column {
        id: shapePanel
        visible: root.pickPhase === "shape" && picker.onPickScreen && root.hasRegion
        z: 80
        spacing: Style.space(14)
        x: picker.localX + Math.max(Style.space(8), Math.round((root.regionW - width) / 2))
        y: picker.localY + Math.max(Style.space(8), Math.round((root.regionH - height) / 2))

        Row {
          spacing: Style.space(22)
          anchors.horizontalCenter: parent.horizontalCenter
          FadeCheck {
            label: "Fade in"
            checked: root.fadeIn
            onToggled: root.fadeIn = !root.fadeIn
          }
          FadeCheck {
            label: "Fade out"
            checked: root.fadeOut
            onToggled: root.fadeOut = !root.fadeOut
          }
          FadeCheck {
            label: "Show keys"
            checked: root.showKeys
            onToggled: {
              root.showKeys = !root.showKeys
              if (!root.showKeys)
                root.keyHudText = ""
              root.savePipPrefs()
            }
          }
        }

        BorderSurface {
          anchors.horizontalCenter: parent.horizontalCenter
          width: borderCol.width + Style.space(24)
          height: borderCol.height + Style.space(16)
          radius: Style.cornerRadius
          color: Util.alpha(Color.background, 0.94)
          borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))

          Column {
            id: borderCol
            anchors.centerIn: parent
            spacing: Style.space(8)

            Row {
              spacing: Style.space(8)
              anchors.horizontalCenter: parent.horizontalCenter

              Text {
                text: "Border"
                textFormat: Text.PlainText
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
              PipBorderSwatch { colorKey: "accent" }
              PipBorderSwatch { colorKey: "red" }
              PipBorderSwatch { colorKey: "yellow" }
              PipBorderSwatch { colorKey: "green" }
              PipBorderSwatch { colorKey: "cyan" }
              PipBorderSwatch { colorKey: "blue" }
              PipBorderSwatch { colorKey: "magenta" }
            }

            Row {
              spacing: Style.space(8)
              anchors.horizontalCenter: parent.horizontalCenter
              PipWidthChip { widthKey: "off" }
              PipWidthChip { widthKey: "thin" }
              PipWidthChip { widthKey: "medium" }
              PipWidthChip { widthKey: "thick" }
            }

            Row {
              spacing: Style.space(10)
              anchors.horizontalCenter: parent.horizontalCenter
              Text {
                text: "Corners"
                textFormat: Text.PlainText
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
              CornerSlider { }
              Text {
                text: root.pipCornerLabel
                textFormat: Text.PlainText
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(48)
              }
            }
            Text {
              text: "Rectangle and square"
              textFormat: Text.PlainText
              color: Util.alpha(Color.popups.text, 0.7)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }

        Text {
          text: "Click a shape to continue"
          textFormat: Text.PlainText
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Grid {
          columns: 2
          spacing: Style.space(14)
          anchors.horizontalCenter: parent.horizontalCenter
          ShapeCard {
            shapeKey: "rectangle"
            label: "Rectangle"
            previewRadius: Picker.cornerPx(root.pipCornerFrac, previewW, previewH)
          }
          ShapeCard {
            shapeKey: "square"
            label: "Square"
            previewW: Style.space(52)
            previewH: Style.space(52)
            previewRadius: Picker.cornerPx(root.pipCornerFrac, previewW, previewH)
          }
          ShapeCard {
            shapeKey: "circle"
            label: "Circle"
            previewW: Style.space(52)
            previewH: Style.space(52)
            previewRadius: Style.space(52) / 2
          }
          ShapeCard {
            shapeKey: "oval"
            label: "Oval"
            previewW: Style.space(64)
            previewH: Style.space(40)
            previewRadius: Style.space(40) / 2
          }
        }

      }
    }
  }

}
