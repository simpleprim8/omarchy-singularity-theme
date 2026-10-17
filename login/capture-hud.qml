import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
    id: root
    property int index: 0
    property var states: ["idle", "checking", "failed", "success"]
    Window {
        visible: true; width: 1280; height: 720; color: "transparent"
        AuthenticationHud {
            id: hud
            anchors.fill: parent
            contextLabel: "ENCRYPTED ROOT // AUTHORIZATION"
            checking: root.states[root.index] === "checking"
            failed: root.states[root.index] === "failed"
            succeeded: root.states[root.index] === "success"
        }
        Timer {
            id: capture
            interval: 100; running: true
            onTriggered: hud.grabToImage(function(result) {
                result.saveToFile(Quickshell.env("SINGULARITY_OUTPUT") + "/hud-" + root.states[root.index] + ".png")
                if (root.index + 1 >= root.states.length) Qt.quit()
                else { root.index++; capture.restart() }
            })
        }
    }
}
