import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
    id: root
    property int index: 0
    Window {
        visible: true; width: 1280; height: 720
        title: "Singularity boot asset renderer"
        SingularityScene {
            id: scene
            width: 1280; height: 720; anchors.centerIn: parent
            animate: false; showLabels: false
            phase: root.index * Math.PI * 2 / (16 * .24)
        }
        Timer {
            id: captureTimer
            interval: 100; running: true
            onTriggered: scene.grabToImage(function(result) {
                result.saveToFile(Quickshell.env("SINGULARITY_OUTPUT") + "/frame-" + root.index + ".png")
                if (root.index + 1 >= 16) Qt.quit()
                else { root.index++; captureTimer.restart() }
            })
        }
    }
}
