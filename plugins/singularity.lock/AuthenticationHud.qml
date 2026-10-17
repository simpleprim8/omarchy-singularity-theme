pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property bool checking: false
    property bool failed: false
    property bool succeeded: false
    property int maskedCount: 0
    property string detail: ""
    property string contextLabel: "SESSION // AUTHORIZATION"
    readonly property real unit: Math.min(width / 1280, height / 720)
    readonly property color accent: succeeded ? "#9bffc2" : (failed ? "#ff8984" : "#75dfb3")
    readonly property string stateLabel: succeeded ? "SOLUTION ACCEPTED" : (failed ? "AUTHORIZATION DENIED" : (checking ? "VERIFYING CREDENTIALS" : "HUMAN AUTHORIZATION REQUIRED"))
    readonly property string headline: succeeded ? "OPTIMAL OMARCHY\nPATH CALCULATED" : "GRAVITATIONAL\nANOMALY DETECTED"
    readonly property string action: succeeded ? "Authorization verified. Session handoff ready." : (failed ? "Credentials not accepted. Type again." : (checking ? "Authentication in progress. Stand by." : "Authorize trajectory recalculation.\nType your password and press Enter."))

    // No timers, sweeps, blinking, pulsing, or animated panel transitions.
    Rectangle {
        id: panel
        x: root.width * .66
        y: root.height * .23
        width: root.width * .30
        height: 420 * root.unit
        color: "#f205100e"
        border.color: "#39665b"; border.width: root.unit
        Rectangle { width: 3 * root.unit; height: 57 * root.unit; color: root.accent }
        Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 45 * root.unit; height: 2 * root.unit; color: root.accent }
        Column {
            x: 21 * root.unit; y: 19 * root.unit
            width: parent.width - 42 * root.unit
            spacing: 13 * root.unit
            Text {
                renderType: Text.NativeRendering;
                width: parent.width
                text: "OMARCHY / CAUSAL NAVIGATION"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 * root.unit; font.letterSpacing: 1 * root.unit
                color: "#86b6a8"
            }
            Row {
                spacing: 8 * root.unit
                Rectangle { width: 6 * root.unit; height: width; y: 4 * root.unit; color: root.accent }
                Text {
                renderType: Text.NativeRendering; text: "SIMULATED TELEMETRY  /  01"; color: root.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 * root.unit }
            }
            Text {
                renderType: Text.NativeRendering;
                width: parent.width; text: root.headline
                color: "#d7f9e9"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22 * root.unit
                font.bold: true; lineHeight: 1.1
            }
            Rectangle { width: parent.width; height: root.unit; color: "#315549" }
            Text {
                renderType: Text.NativeRendering;
                width: parent.width; text: "MODEL    TIMELIKE GEODESIC\nDOMAIN   OUTSIDE EVENT HORIZON\nTARGET   FUTURE-DIRECTED PATH"
                color: "#86ad9f"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 * root.unit; lineHeight: 1.55
            }
            Text {
                renderType: Text.NativeRendering;
                width: parent.width; text: root.stateLabel
                color: root.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 * root.unit; font.bold: true
                wrapMode: Text.Wrap
            }
            Text {
                renderType: Text.NativeRendering;
                width: parent.width; text: root.action
                color: "#d0e9de"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 * root.unit
                wrapMode: Text.Wrap; lineHeight: 1.4
            }
            Text {
                renderType: Text.NativeRendering;
                width: parent.width; text: root.detail || root.contextLabel
                color: root.failed ? root.accent : "#7b9d90"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 * root.unit
                wrapMode: Text.Wrap; textFormat: Text.PlainText
            }
            Rectangle { width: parent.width; height: root.unit; color: "#315549" }
            Text {
                renderType: Text.NativeRendering;
                width: parent.width; text: "SINGULARITY NEAR. HUMAN IN THE LOOP.\nR.K. / 2045  —  FORECAST, NOT A DEADLINE."
                color: "#739589"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8 * root.unit; lineHeight: 1.55
            }
        }
    }
    // Instrument reticle: stationary, with an interrupted leader to the HUD.
    Rectangle {
        x: root.width * .5 - 27 * root.unit; y: root.height * .59 - 27 * root.unit
        width: 54 * root.unit; height: width; radius: width / 2
        color: "transparent"; border.color: "#466d5c"; border.width: root.unit
    }
    Rectangle { x: root.width * .5 + 34 * root.unit; y: root.height * .59; width: root.width * .13; height: root.unit; color: "#385b4e" }
}
