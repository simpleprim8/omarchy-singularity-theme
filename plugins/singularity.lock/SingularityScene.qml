pragma ComponentBehavior: Bound
import QtQuick
import "VortexMath.js" as Vortex

Item {
    id: root
    // Presentation data only. Password text stays in the native input/PAM path.
    property int maskedCount: 0
    readonly property int renderedCount: Math.max(0, Math.min(128, maskedCount))
    property bool checking: false
    property string message: ""
    property string contextLabel: "SESSION // AUTHORIZATION"
    property bool succeeded: false
    property bool failed: false
    property bool animate: true
    property bool showLabels: true
    property real phase: 0
    property real travel: 0
    property real swallow: 0
    property real entryDrift: 0
    readonly property point throat: Vortex.point(0, 0, phase, width, height)
    readonly property real unit: Math.min(width / 1280, height / 720)
    clip: true

    onMaskedCountChanged: {
        travel = renderedCount
    }
    onCheckingChanged: {
        if (checking) consume.restart()
        else { consume.stop(); swallow = 0 }
    }
    Behavior on travel { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    NumberAnimation { id: consume; target: root; property: "swallow"; to: 28; duration: 1000; easing.type: Easing.InCubic }
    Rectangle { anchors.fill: parent; color: "#020704" }
    ShaderEffect {
        anchors.fill: parent
        property vector2d resolution: Qt.vector2d(width, height)
        property real phase: 0
        vertexShader: Qt.resolvedUrl("login.vert.qsb")
        fragmentShader: Qt.resolvedUrl("login.frag.qsb")
        mesh: GridMesh { resolution: Qt.size(192, 192) }
        cullMode: ShaderEffect.NoCulling
        blending: true
    }
    // A restrained event horizon leaves the mesh itself readable.
    Rectangle {
        x: root.throat.x - width/2; y: root.throat.y - height/2
        width: 30 * root.unit; height: width; radius: width/2
        color: "#092216"; opacity: 0.55
        Rectangle { anchors.centerIn: parent; width: parent.width*.6; height: width; radius: width/2; color: "#010402"; border.color: "#376b4c"; border.width: root.unit }
    }
    Repeater {
        objectName: "passwordDots"
        model: root.renderedCount
        delegate: Item {
            id: bead
            required property int index
            readonly property real step: Math.max(0, root.travel - 1 - index + root.entryDrift + root.swallow)
            readonly property real radiusOnGrid: Vortex.radius(step)
            readonly property point projected: Vortex.point(radiusOnGrid, Math.PI/2, root.phase, root.width, root.height)
            readonly property real size: root.unit * (3 + 7 * Math.exp(-step * .045))
            x: projected.x; y: projected.y
            opacity: Math.min(1, radiusOnGrid / 0.8) * Math.max(0, Math.min(1, (32 - step) / 5))
            Rectangle {
                anchors.centerIn: parent
                width: bead.size * 3; height: width; radius: width/2
                color: root.failed ? "#ec8181" : "#59d98b"; opacity: .13
            }
            Rectangle {
                anchors.centerIn: parent
                width: bead.size; height: width; radius: width/2
                color: root.failed ? "#f3a4a0" : "#dcffe8"
            }
        }
    }
    AuthenticationHud {
        anchors.fill: parent
        visible: root.showLabels
        checking: root.checking
        failed: root.failed
        succeeded: root.succeeded
        maskedCount: root.maskedCount
        detail: root.failed ? root.message : ""
        contextLabel: root.contextLabel
    }
}
