import QtQuick

Item {
    id: root
    property real phase: 0
    clip: true
    layer.enabled: true
    layer.textureSize: Qt.size(Math.min(1920, Math.ceil(width * 2)), Math.min(1080, Math.ceil(height * 2)))
    layer.smooth: true

    Rectangle { anchors.fill: parent; color: "#000402" }
    ShaderEffect {
        anchors.fill: parent
        property vector2d resolution: Qt.vector2d(width, height)
        property real phase: root.phase
        vertexShader: Qt.resolvedUrl("spacetime.vert.qsb")
        fragmentShader: Qt.resolvedUrl("spacetime.frag.qsb")
        mesh: GridMesh { resolution: Qt.size(96, 128) }
        cullMode: ShaderEffect.NoCulling
        blending: true
    }
}
