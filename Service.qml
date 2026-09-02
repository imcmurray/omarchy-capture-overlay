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
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || ""

  property bool recording: false
  property bool hasRegion: false
  property int regionX: 0
  property int regionY: 0
  property int regionW: 0
  property int regionH: 0
  property bool forced: false

  property bool picking: false
  property string pickPhase: "idle" // idle, drag, adjust, resize, move
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
  property int countdownValue: 3
  property int camX: 0
  property int camY: 0
  property int camW: 0
  property int camH: 0
  property bool camAnimating: false
  property bool camDidDrag: false
  property bool camPreviewActive: false
  property bool camSidecarStopping: false
  property bool wasRecording: false
  readonly property string camSidecar: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-cam-sidecar.mp4"

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
      item.webcamShape = Qt.binding(function() { return root.webcamShape })
      item.showCountdown = Qt.binding(function() { return root.pickPhase === "countdown" })
      item.countdownValue = Qt.binding(function() { return root.countdownValue })
      item.failed.connect(function() { root.camPreviewActive = false })
      item.sidecarStopped.connect(function() {
        if (root.camSidecarStopping)
          root.camPreviewActive = false
      })
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
    root.webcamShape = shape === "circle" ? "circle" : "rectangle"
    return root.beginWebcamPlace()
  }

  function grabPlacement() {
    if (root.webcamShape === "circle") {
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
    w = Math.max(48, Math.round(w))
    h = Math.max(48, Math.round(h))
    if (root.hasRegion) {
      x = Math.max(root.regionX, Math.min(Math.round(x), root.regionX + root.regionW - w))
      y = Math.max(root.regionY, Math.min(Math.round(y), root.regionY + root.regionH - h))
    } else {
      x = Math.round(x)
      y = Math.round(y)
    }
    return { x: x, y: y, w: w, h: h }
  }

  function persistCam() {
    Quickshell.execDetached([
      root.pluginDir + "/bin/cam-update",
      String(root.camX), String(root.camY), String(root.camW), String(root.camH)
    ])
  }

  function dragCam(x, y) {
    root.camAnimating = false
    root.camDidDrag = true
    var p = root.clampCamPos(x, y, root.camW, root.camH)
    root.camX = p.x
    root.camY = p.y
  }

  function finishCamDrag() {
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
    if (root.webcamShape === "circle") {
      fillW = Math.min(root.regionW, root.regionH)
      fillH = fillW
    }
    var pct = fillW > 0 ? (root.camW * 100 / fillW) : 100
    var frac = 100
    if (action === "large") frac = 55
    else if (action === "medium") frac = 35
    else if (action === "small") frac = 22
    else if (action === "smaller") {
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
    var p = root.grabPlacement()
    root.camAnimating = false
    root.camX = p.x
    root.camY = p.y
    root.camW = p.w
    root.camH = p.h
    Qt.callLater(function() { root.camAnimating = true })
    var region = root.regionW + "x" + root.regionH + "+" + root.regionX + "+" + root.regionY
    Quickshell.execDetached([root.pluginDir + "/bin/start-cam", root.webcamShape, region])
    root.camSidecarStopping = false
    root.camPreviewActive = true
    return "place"
  }

  function stopWebcamPreview() {
    root.camSidecarStopping = true
    if (camEngine.item)
      camEngine.item.stopSidecar()
    root.camPreviewActive = false
    Quickshell.execDetached([root.pluginDir + "/bin/stop-cam"])
  }

  function startCountdown() {
    if (!root.hasRegion)
      return "empty"
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
    else if (root.camPreviewActive && camEngine.item) {
      root.camSidecarStopping = false
      camEngine.item.startSidecar(root.camSidecar)
    }
    if (root.selectionFile && root.doneFile) {
      Quickshell.execDetached([
        root.pluginDir + "/bin/finish-pick",
        geo,
        root.selectionFile,
        status,
        root.doneFile,
        shape
      ])
    }
    root.picking = false
    root.pickPhase = "idle"
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
    if (mouse.button === Qt.RightButton) {
      root.finishPick(false)
      return
    }
    if (root.pickPhase === "shape" || root.pickPhase === "countdown" || root.pickPhase === "place")
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
    if (root.pickPhase === "shape" || root.pickPhase === "countdown" || root.pickPhase === "place")
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
    if (root.pickPhase === "shape" || root.pickPhase === "countdown" || root.pickPhase === "place")
      return
    if (root.hasRegion)
      root.confirmRegion()
  }

  function handleKeys(event) {
    if (event.key === Qt.Key_Escape) {
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
      if (event.key === Qt.Key_Left || event.key === Qt.Key_R)
        root.webcamShape = "rectangle"
      else if (event.key === Qt.Key_Right || event.key === Qt.Key_C)
        root.webcamShape = "circle"
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

  Component.onCompleted: refresh()

  Timer {
    interval: 400
    running: true
    repeat: true
    onTriggered: root.refresh()
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
    required property int sx
    required property int sy
    visible: root.camPreviewActive && root.camW > 0
    x: root.camX - sx
    y: root.camY - sy
    width: Math.max(1, root.camW)
    height: Math.max(1, root.camH)

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      property real grabX: 0
      property real grabY: 0
      onPressed: function(mouse) {
        grabX = mouse.x
        grabY = mouse.y
      }
      onPositionChanged: function(mouse) {
        if (!pressed)
          return
        root.dragCam(root.camX + mouse.x - grabX, root.camY + mouse.y - grabY)
      }
      onReleased: root.finishCamDrag()
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
      WlrLayershell.namespace: "ianm-capture-overlay"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: livePip.visible ? livePipHit : livePass

      Region { id: livePass }
      Region { id: livePipHit; item: livePip }

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

      Canvas {
        id: liveDim
        anchors.fill: parent
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          ctx.globalCompositeOperation = "source-over"
          ctx.fillStyle = root.dimColor
          ctx.fillRect(0, 0, width, height)
          ctx.globalCompositeOperation = "destination-out"
          ctx.fillRect(live.holeX, live.holeY, live.holeW, live.holeH)
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
          target: root
          function onRegionXChanged() { liveDim.requestPaint() }
          function onRegionYChanged() { liveDim.requestPaint() }
          function onRegionWChanged() { liveDim.requestPaint() }
          function onRegionHChanged() { liveDim.requestPaint() }
          function onCamWChanged() { liveDim.requestPaint() }
          function onPickingChanged() { liveDim.requestPaint() }
        }
        Component.onCompleted: requestPaint()
      }

      CaptureFrame {
        anchors.fill: parent
        localX: live.localX
        localY: live.localY
        localW: root.regionW
        localH: root.regionH
        showHandles: false
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
              ? "REC  " + root.sizeLabel + "  ·  drag camera  ·  Super+Alt+[ ]"
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
      // Clicks pass through so the camera can be dragged. The webcam window
      // is no_focus so Enter/Esc stay on this exclusive keyboard grab.
      mask: !root.picking
        ? passClicks
        : ((root.pickPhase === "place" || root.pickPhase === "countdown")
          ? (pickPip.visible ? pickPipHit : passClicks)
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
        hoverEnabled: root.pickPhase !== "shape" && root.pickPhase !== "place" && root.pickPhase !== "countdown"
        acceptedButtons: (root.pickPhase === "shape" || root.pickPhase === "place" || root.pickPhase === "countdown")
          ? Qt.RightButton
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

      Rectangle { x: 0; y: 0; width: picker.width; height: root.hasRegion && picker.onPickScreen ? picker.holeY : picker.height; color: root.dimColor }
      Rectangle {
        visible: root.hasRegion && picker.onPickScreen
        x: 0
        y: picker.holeY + picker.holeH
        width: picker.width
        height: Math.max(0, picker.height - picker.holeY - picker.holeH)
        color: root.dimColor
      }
      Rectangle {
        visible: root.hasRegion && picker.onPickScreen && picker.holeX > 0 && picker.holeH > 0
        x: 0
        y: picker.holeY
        width: picker.holeX
        height: picker.holeH
        color: root.dimColor
      }
      Rectangle {
        visible: root.hasRegion && picker.onPickScreen && picker.holeH > 0
        x: picker.holeX + picker.holeW
        y: picker.holeY
        width: Math.max(0, picker.width - picker.holeX - picker.holeW)
        height: picker.holeH
        color: root.dimColor
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
                return "Drag the camera to a corner · Super+Alt+[ ] · Enter to countdown"
              if (root.pickPhase === "shape")
                return "Webcam shape · R rectangle · C circle · Enter to record"
              if (root.hasRegion)
                return root.sizeLabel + "   Enter to record · drag edges or click a size guide"
              return "Drag a region · snap guides are 1080p / 720p / 900p · Esc to cancel"
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

      Row {
        visible: root.pickPhase === "shape" && picker.onPickScreen
        z: 20
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(18)

        BorderSurface {
          width: Style.space(148)
          height: Style.space(168)
          radius: Style.cornerRadius
          color: Util.alpha(Color.background, 0.94)
          borderSpec: Border.surfaceSpec("popups", "border", root.webcamShape === "rectangle" ? Color.accent : Color.popups.border, Math.max(1, Style.space(root.webcamShape === "rectangle" ? 3 : 2)))

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(16)
            spacing: Style.space(12)
            Item {
              width: parent.width
              height: Style.space(88)
              Rectangle {
                anchors.centerIn: parent
                width: Style.space(52)
                height: Style.space(72)
                radius: 2
                color: Util.alpha(Color.accent, 0.35)
                border.color: Color.accent
                border.width: 2
              }
            }
            Text {
              width: parent.width
              text: "Rectangle"
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
            onClicked: root.chooseWebcamShape("rectangle")
          }
        }

        BorderSurface {
          width: Style.space(148)
          height: Style.space(168)
          radius: Style.cornerRadius
          color: Util.alpha(Color.background, 0.94)
          borderSpec: Border.surfaceSpec("popups", "border", root.webcamShape === "circle" ? Color.accent : Color.popups.border, Math.max(1, Style.space(root.webcamShape === "circle" ? 3 : 2)))

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(16)
            spacing: Style.space(12)
            Item {
              width: parent.width
              height: Style.space(88)
              Rectangle {
                anchors.centerIn: parent
                width: Style.space(72)
                height: Style.space(72)
                radius: width / 2
                color: Util.alpha(Color.accent, 0.35)
                border.color: Color.accent
                border.width: 2
              }
            }
            Text {
              width: parent.width
              text: "Circle"
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
            onClicked: root.chooseWebcamShape("circle")
          }
        }
      }
    }
  }

}
