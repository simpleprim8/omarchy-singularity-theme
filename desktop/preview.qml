import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property real elapsed: Number(Quickshell.env("SPACETIME_TIME") || "0")
    property bool paused: Quickshell.env("SPACETIME_CAPTURE") === "1"
    property real rate: 1
    property double lastTick: Date.now()
    Timer {
        interval: 16; running: !root.paused; repeat: true
        onTriggered: {
            let now = Date.now()
            root.elapsed = (root.elapsed + Math.min(0.25, (now-root.lastTick)/1000)*root.rate) % 450
            root.lastTick = now
        }
    }
    IpcHandler {
        target: "spacetime"
        function seek(seconds: real): void { root.elapsed = ((seconds % 450) + 450) % 450 }
        function pause(): void { root.paused = true }
        function resume(): void { root.lastTick = Date.now(); root.paused = false }
        function speed(value: real): void { root.rate = Math.max(0.1, Math.min(value, 30)) }
        function status(): string { return JSON.stringify({seconds: root.elapsed, paused: root.paused, speed: root.rate}) }
    }
    Window {
        id: win
        visible: true
        width: 1100; height: 650
        title: "Spacetime — five perspectives · 90 seconds each"
        color: "black"
        Spacetime { id: effect; anchors.fill: parent; phase: root.elapsed }
        Timer {
            interval: 1400; running: root.paused && Quickshell.env("SPACETIME_CAPTURE") === "1"
            onTriggered: effect.grabToImage(function(result) {
                result.saveToFile(Quickshell.env("SPACETIME_OUTPUT"))
                Qt.quit()
            })
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.lastTick = Date.now()
                root.paused = !root.paused
            }
        }
    }
}
