import QtQuick
import QtMultimedia
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property var camScreen: null
  property int camX: 0
  property int camY: 0
  property int camW: 0
  property int camH: 0
  property real camRot: 0
  property real camInsetL: 0
  property real camInsetT: 0
  property real camInsetR: 0
  property real camInsetB: 0
  property string webcamShape: "rectangle"
  property bool showCountdown: false
  property int countdownValue: 3
  property color pipBorderColor: "#ffffff"
  property int pipBorderWidth: 0
  property real pipRadius: 0
  property string cameraId: ""
  property string cameraName: ""
  property bool cameraReady: false
  readonly property bool circle: root.webcamShape === "circle"
  readonly property bool oval: root.webcamShape === "oval"
  readonly property bool round: root.circle || root.oval
  readonly property bool needsMask: root.round || root.pipRadius > 0.5
  readonly property alias cameraModel: cameraList
  readonly property int cameraCount: cameraList.count

  signal failed()
  signal deviceResolved(string id, string name)

  component EllipseShape: Shape {
    id: ell
    property color fillCol: "transparent"
    property color strokeCol: "transparent"
    property real strokePx: 0
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true
    ShapePath {
      fillColor: ell.fillCol
      strokeColor: ell.strokeCol
      strokeWidth: ell.strokePx
      PathAngleArc {
        centerX: ell.width / 2
        centerY: ell.height / 2
        radiusX: Math.max(1, ell.width / 2)
        radiusY: Math.max(1, ell.height / 2)
        startAngle: 0
        sweepAngle: 360
      }
    }
  }

  MediaDevices {
    id: mediaDevices
    onVideoInputsChanged: root.refreshCameras()
  }

  ListModel { id: cameraList }

  function refreshCameras() {
    var list = mediaDevices.videoInputs
    cameraList.clear()
    if (!list)
      return
    var pending = []
    var nameCount = {}
    for (var i = 0; i < list.length; i++) {
      var dev = list[i]
      if (!root.pickCamFormat(dev))
        continue
      var id = "" + dev.id
      var name = String(dev.description || "").trim()
      if (!name)
        name = id
      pending.push({ camId: id, camName: name })
      nameCount[name] = (nameCount[name] || 0) + 1
    }
    for (var j = 0; j < pending.length; j++) {
      var row = pending[j]
      var label = row.camName
      if (nameCount[label] > 1)
        label = label + " · " + row.camId.replace(/^.*\//, "")
      cameraList.append({ camId: row.camId, camName: label, camDesc: row.camName })
    }
  }

  function matchDevice() {
    var list = mediaDevices.videoInputs
    var fallback = mediaDevices.defaultVideoInput
    if (!list || list.length === 0)
      return fallback
    var i
    if (root.cameraId) {
      for (i = 0; i < list.length; i++) {
        if ("" + list[i].id === root.cameraId)
          return list[i]
      }
    }
    if (root.cameraName) {
      for (i = 0; i < list.length; i++) {
        if ("" + list[i].description === root.cameraName)
          return list[i]
      }
    }
    return fallback || list[0]
  }

  // Some UVC cams expose YUYV 1080p at 5fps as the default; Qt will pick
  // that and the recording stutters. Prefer 24fps+ at most 720p.
  function pickCamFormat(device) {
    if (!device)
      return undefined
    var formats = device.videoFormats
    if (!formats || formats.length === 0)
      return undefined
    var best = undefined
    var bestCapped = false
    var bestFps = -1
    var bestArea = -1
    for (var i = 0; i < formats.length; i++) {
      var f = formats[i]
      var w = f.resolution.width
      var h = f.resolution.height
      var fps = f.maxFrameRate
      if (w < 160 || h < 120)
        continue
      var capped = fps >= 24 && w <= 1280 && h <= 720
      var area = w * h
      if (!best
          || (capped && !bestCapped)
          || (capped === bestCapped && fps > bestFps + 0.5)
          || (capped === bestCapped && Math.abs(fps - bestFps) <= 0.5 && area > bestArea)) {
        best = f
        bestCapped = capped
        bestFps = fps
        bestArea = area
      }
    }
    return best
  }

  Camera {
    id: camera
    cameraDevice: root.matchDevice()
    cameraFormat: root.pickCamFormat(cameraDevice)
    active: root.cameraReady
    onErrorOccurred: function() { root.failed() }
    onCameraDeviceChanged: {
      if (!cameraDevice)
        return
      root.deviceResolved("" + cameraDevice.id, "" + (cameraDevice.description || ""))
    }
  }

  Component.onCompleted: root.refreshCameras()

  CaptureSession {
    camera: camera
    videoOutput: camVideo
  }

  PanelWindow {
    id: camLayer
    visible: root.camScreen && root.camW > 0
    screen: root.camScreen
    color: "transparent"
    surfaceFormat.opaque: false
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "ianm-cam-preview"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    readonly property int sx: root.camScreen ? root.camScreen.x : 0
    readonly property int sy: root.camScreen ? root.camScreen.y : 0

    Item {
      id: pipFrame
      x: root.camX - camLayer.sx
      y: root.camY - camLayer.sy
      width: Math.max(1, root.camW)
      height: Math.max(1, root.camH)
      rotation: root.oval ? root.camRot : 0
      transformOrigin: Item.Center
      clip: true

      readonly property real cropW: Math.max(0.3, 1 - root.camInsetL - root.camInsetR)
      readonly property real cropH: Math.max(0.3, 1 - root.camInsetT - root.camInsetB)

      // Keep a 1px sink so CaptureSession stays alive; hide the plane off-screen
      // during countdown so it cannot cover the 3-2-1 surface.
      VideoOutput {
        id: camVideo
        x: root.showCountdown ? -4 : -root.camInsetL * width
        y: root.showCountdown ? -4 : -root.camInsetT * height
        width: root.showCountdown ? 1 : parent.width / pipFrame.cropW
        height: root.showCountdown ? 1 : parent.height / pipFrame.cropH
        fillMode: VideoOutput.PreserveAspectCrop
        visible: !root.showCountdown && !root.needsMask
        opacity: root.showCountdown ? 0 : 1
      }

      Loader {
        active: root.needsMask && !root.showCountdown
        x: camVideo.x
        y: camVideo.y
        width: camVideo.width
        height: camVideo.height
        sourceComponent: Item {
          anchors.fill: parent

          Item {
            id: roundMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            EllipseShape {
              visible: root.round
              x: root.camInsetL * parent.width
              y: root.camInsetT * parent.height
              width: pipFrame.width
              height: pipFrame.height
              fillCol: "#ffffff"
            }
            Rectangle {
              visible: !root.round
              x: root.camInsetL * parent.width
              y: root.camInsetT * parent.height
              width: pipFrame.width
              height: pipFrame.height
              radius: Math.max(0, root.pipRadius)
              color: "#ffffff"
              antialiasing: true
            }
          }

          MultiEffect {
            anchors.fill: parent
            source: camVideo
            maskEnabled: true
            maskSource: roundMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.02
          }
        }
      }

      // Drawn on the live pip, so gpu-screen-recorder captures it.
      Rectangle {
        anchors.fill: parent
        visible: !root.showCountdown && root.pipBorderWidth > 0 && !root.oval
        color: "transparent"
        radius: root.circle ? Math.min(width, height) / 2 : Math.max(0, root.pipRadius)
        border.color: root.pipBorderColor
        border.width: Math.max(0, root.pipBorderWidth)
        antialiasing: true
        z: 20
      }

      EllipseShape {
        anchors.fill: parent
        visible: !root.showCountdown && root.pipBorderWidth > 0 && root.oval
        z: 20
        strokeCol: root.pipBorderColor
        strokePx: Math.max(1, root.pipBorderWidth)
      }
    }
  }

  PanelWindow {
    visible: root.showCountdown && root.camScreen && root.camW > 0
    screen: root.camScreen
    color: "transparent"
    surfaceFormat.opaque: false
    implicitWidth: Math.max(1, root.camW)
    implicitHeight: Math.max(1, root.camH)
    anchors.left: true
    anchors.top: true
    margins.left: Math.max(0, root.camX - (root.camScreen ? root.camScreen.x : 0))
    margins.top: Math.max(0, root.camY - (root.camScreen ? root.camScreen.y : 0))
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "ianm-capture-countdown"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: countFill }

    Rectangle {
      id: countFill
      anchors.fill: parent
      radius: root.circle ? width / 2 : (root.oval ? Math.min(width, height) / 2 : Math.max(0, root.pipRadius))
      color: Util.alpha(Color.background, 0.94)
      border.color: Color.accent
      border.width: Math.max(3, Style.space(4))

      Text {
        anchors.centerIn: parent
        text: String(root.countdownValue)
        textFormat: Text.PlainText
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Math.round(Math.min(countFill.width, countFill.height) * 0.52)
        font.bold: true
      }
    }
  }
}
