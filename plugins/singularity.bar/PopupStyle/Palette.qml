pragma Singleton
import QtQuick
import qs.Commons
QtObject {
  readonly property color green: Color.pick("popups.green", "#59d98b")
  readonly property color title: Color.pick("popups.title", "#b4a0d2")
  readonly property color orange: Color.pick("popups.active", "#dca276")
  readonly property color blue: Color.pick("popups.description", "#86b3d1")
  readonly property color muted: Color.pick("popups.inactive", "#819bb6")
  readonly property color text: Color.popups.text
  readonly property string bodyFont: Style.font.family
  readonly property string titleFont: face.status === FontLoader.Ready ? face.name : Style.font.family
  property FontLoader face: FontLoader { source: Qt.resolvedUrl("fonts/Rajdhani-Medium.ttf") }
}
