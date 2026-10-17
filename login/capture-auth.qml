import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
    id: root
    property int index: 0
    property var shots: [
        { name: "idle-a", count: 0, drift: 0, state: "idle", phase: 0 },
        { name: "idle-b", count: 0, drift: 0, state: "idle", phase: 27 },
        { name: "dots-a", count: 8, drift: 0, state: "idle", phase: 0 },
        { name: "dots-b", count: 8, drift: 5, state: "idle", phase: 0 },
        { name: "failed", count: 0, drift: 0, state: "failed", phase: 0 },
        { name: "success", count: 0, drift: 0, state: "success", phase: 0 },
        { name: "frame-0", count: 0, drift: 0, state: "background", phase: 0 }
    ]
    readonly property var shot: shots[index]
    Window {
        visible: true; width: 1280; height: 720
        title: "Singularity authentication render"
        SingularityScene {
            id: scene
            width: 1280; height: 720; anchors.centerIn: parent
            animate: false
            phase: root.shot.phase
            maskedCount: root.shot.count
            entryDrift: root.shot.drift
            failed: root.shot.state === "failed"
            succeeded: root.shot.state === "success"
            showLabels: root.shot.state !== "background"
            message: failed ? "Credentials not accepted. Type again." : ""
        }
        Timer {
            id: capture
            interval: 700; running: true
            onTriggered: scene.grabToImage(function(result) {
                result.saveToFile(Quickshell.env("SINGULARITY_OUTPUT") + "/" + root.shot.name + ".png")
                if (root.index + 1 >= root.shots.length) Qt.quit()
                else { root.index++; capture.restart() }
            })
        }
    }
}
