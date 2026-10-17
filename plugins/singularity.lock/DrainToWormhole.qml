import QtQuick

ShaderEffect {
  id: root

  property vector2d resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
  property vector2d center: Qt.vector2d(0.5, 0.5)
  property real startedAtMs: 0
  property real phase: 0
  property real seed: 0.31
  property string desktopCaptureUrl: ""
  property variant desktopSource: captureTexture

  fragmentShader: Qt.resolvedUrl("drain.frag.qsb")

  Image {
    id: captureImage
    width: root.width
    height: root.height
    source: root.desktopCaptureUrl
    fillMode: Image.PreserveAspectCrop
    asynchronous: false
    cache: false
  }

  ShaderEffectSource {
    id: captureTexture
    visible: false
    sourceItem: captureImage
    hideSource: true
    live: false
  }

  Timer {
    interval: 33
    repeat: true
    running: root.visible
    onTriggered: root.phase = Math.max(0, (Date.now() - root.startedAtMs) / 1000)
  }
}
