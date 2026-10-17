import QtQuick
import QtTest
import ".."
TestCase {
    name: "BoundedPasswordDisplay"
    when: windowShown
    SingularityScene { id: scene; width: 1280; height: 720; showLabels: false }
    function test_extreme_count_bounds_work_without_truncating_native_count() {
        scene.maskedCount = 10000
        compare(scene.maskedCount, 10000)
        compare(scene.renderedCount, 128)
        var dots = findChild(scene, "passwordDots")
        verify(dots !== null)
        compare(dots.count, 128)
        scene.maskedCount = -1
        compare(dots.count, 0)
        scene.maskedCount = 12
        compare(dots.count, 12)
    }
}
