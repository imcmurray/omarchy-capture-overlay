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
  readonly property bool circle: root.webcamShape === "circle"
  readonly property bool oval: root.webcamShape === "oval"
  readonly property bool round: root.circle || root.oval

  signal failed()

  component EllipseFill: Shape {
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true
    ShapePath {
      fillColor: "#ffffff"
      strokeWidth: 0
      PathAngleArc {
        centerX: width / 2
        centerY: height / 2
        radiusX: Math.max(1, width / 2)
        radiusY: Math.max(1, height / 2)
        startAngle: 0
        sweepAngle: 360
      }
    }
  }

  MediaDevices { id: mediaDevices }

  // C920 YUYV 1080p is 5fps; Qt's default can pick that and the recording
  // stutters. Prefer a 30fps mode at most 720p (MJPEG 1280x720 on a C920).
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
    cameraDevice: {
      var list = mediaDevices.videoInputs
      for (var i = 0; i < list.length; i++) {
        var id = "" + list[i].id
        var desc = "" + list[i].description
        if (id.indexOf("video0") !== -1 || desc.indexOf("C920") !== -1 || desc.indexOf("HD Pro") !== -1)
          return list[i]
      }
      return mediaDevices.defaultVideoInput
    }
    cameraFormat: root.pickCamFormat(cameraDevice)
    active: true
    onErrorOccurred: function() { root.failed() }
  }

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
        visible: !root.showCountdown && !root.round
        opacity: root.showCountdown ? 0 : 1
      }

      Loader {
        active: root.round && !root.showCountdown
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
            EllipseFill {
              x: root.camInsetL * parent.width
              y: root.camInsetT * parent.height
              width: pipFrame.width
              height: pipFrame.height
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
        radius: root.circle ? Math.min(width, height) / 2 : 0
        border.color: root.pipBorderColor
        border.width: Math.max(0, root.pipBorderWidth)
        antialiasing: true
        z: 20
      }

      Shape {
        anchors.fill: parent
        visible: !root.showCountdown && root.pipBorderWidth > 0 && root.oval
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        z: 20
        ShapePath {
          fillColor: "transparent"
          strokeColor: root.pipBorderColor
          strokeWidth: Math.max(1, root.pipBorderWidth)
          PathAngleArc {
            centerX: width / 2
            centerY: height / 2
            radiusX: Math.max(1, width / 2)
            radiusY: Math.max(1, height / 2)
            startAngle: 0
            sweepAngle: 360
          }
        }
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
      radius: root.circle ? width / 2 : (root.oval ? Math.min(width, height) / 2 : 0)
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
