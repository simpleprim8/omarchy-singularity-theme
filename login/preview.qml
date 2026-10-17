import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
    id: root
    property int index: 0
    property var counts: [0, 1, 8, 20, 64]
    Window {
        visible: true; width: 1280; height: 720
        title: "Singularity unlock visual preview"
        SingularityScene {
            id: scene
            width: 1280; height: 720
            anchors.centerIn: parent
            animate: Quickshell.env("SINGULARITY_CAPTURE") !== "1"
            maskedCount: root.counts[root.index]
            message: maskedCount ? "Enter to unlock" : "Enter password"
        }
        Timer {
            interval: 700; running: Quickshell.env("SINGULARITY_CAPTURE") === "1"
            onTriggered: scene.grabToImage(function(result) {
                result.saveToFile(Quickshell.env("SINGULARITY_OUTPUT") + "/lock-" + root.counts[root.index] + ".png")
                if (root.index + 1 >= root.counts.length) Qt.quit()
                else { root.index++; restart() }
            })
        }
    }
}
