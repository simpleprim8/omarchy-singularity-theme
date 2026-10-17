import QtQuick

// Visual drift only. Reaching the center never invalidates or clears input.
// Password text remains exclusively with its native input/authentication owner.
Item {
    id: root
    property int maskedCount: 0
    property bool checking: false
    property bool active: true
    property int durationMs: 12000
    property double startedAtMs: 0
    property real drift: 0
    readonly property real swallowStep: 32

    function reset() { startedAtMs = 0; drift = 0 }
    function updateDrift() {
        if (!active || checking || !maskedCount || !startedAtMs) return
        drift = swallowStep * Math.min(1, Math.max(0, Date.now() - startedAtMs) / durationMs)
    }
    function synchronize() {
        if (!active || !maskedCount) { reset(); return }
        if (checking) return
        if (!startedAtMs) startedAtMs = Date.now()
        updateDrift()
    }
    onMaskedCountChanged: {
        // Once the visual trail has vanished, further edits reveal it again.
        // The native buffer is never cleared or invalidated by this clock.
        if (drift >= swallowStep) reset()
        synchronize()
    }
    onCheckingChanged: synchronize()
    onActiveChanged: synchronize()
    Component.onCompleted: synchronize()
    Timer {
        interval: 16; repeat: true
        running: root.active && !root.checking && root.maskedCount > 0 && root.startedAtMs > 0 && root.drift < root.swallowStep
        onTriggered: root.updateDrift()
    }
}
