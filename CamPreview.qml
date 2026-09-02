import QtQuick
import QtMultimedia
import QtQuick.Effects
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
  property string webcamShape: "rectangle"
  property bool showCountdown: false
  property int countdownValue: 3
  readonly property bool circle: root.webcamShape === "circle"

  signal failed()

  MediaDevices { id: mediaDevices }

  Camera {
    id: camera
    active: true
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

      // Keep a 1px sink so CaptureSession stays alive; hide the plane off-screen
      // during countdown so it cannot cover the 3-2-1 surface.
      VideoOutput {
        id: camVideo
        x: root.showCountdown ? -4 : 0
        y: root.showCountdown ? -4 : 0
        width: root.showCountdown ? 1 : parent.width
        height: root.showCountdown ? 1 : parent.height
        fillMode: VideoOutput.PreserveAspectCrop
        visible: !root.showCountdown && !root.circle
        opacity: root.showCountdown ? 0 : 1
      }

      Loader {
        anchors.fill: parent
        active: root.circle && !root.showCountdown
        sourceComponent: Item {
          anchors.fill: parent

          Item {
            id: circleMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            Rectangle {
              anchors.fill: parent
              radius: Math.min(width, height) / 2
              color: "#ffffff"
            }
          }

          MultiEffect {
            anchors.fill: parent
            source: camVideo
            maskEnabled: true
            maskSource: circleMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.02
          }

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: Math.min(width, height) / 2
            border.color: Color.accent
            border.width: Math.max(2, Style.space(2))
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
      radius: root.circle ? width / 2 : 0
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
