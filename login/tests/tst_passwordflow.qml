import QtQuick
import QtTest
import ".."

TestCase {
    id: test
    name: "PasswordFlow"
    when: windowShown
    TextInput { id: input }
    PasswordFlow { id: flow; maskedCount: input.text.length }
    function init() {
        input.text = ""
        flow.checking = false
        flow.active = true
        flow.durationMs = 12000
        flow.reset()
    }
    function test_first_character_moves_without_more_typing() {
        input.text = "x"
        wait(50)
        verify(flow.drift > 0)
    }
    function test_append_and_backspace_keep_visual_clock() {
        input.text = "x"
        var start = flow.startedAtMs
        wait(20)
        input.text = "xxxx"
        compare(flow.startedAtMs, start)
        input.text = "xx"
        compare(flow.startedAtMs, start)
    }
    function test_disappeared_dots_never_reject_or_clear_input() {
        flow.durationMs = 40
        input.text = "synthetic"
        tryCompare(flow, "drift", 32)
        compare(input.text, "synthetic")
        flow.startedAtMs = Date.now() - 600000
        input.text += "-late-edit"
        compare(input.text, "synthetic-late-edit")
        verify(flow.drift < 32)
        // Simulate the native owner's normal submission and failed retry.
        input.text = ""
        compare(flow.startedAtMs, 0)
        input.text = "retry"
        verify(flow.startedAtMs > 0)
        verify(flow.drift < 32)
    }
    function test_checking_holds_dot_positions() {
        input.text = "synthetic"
        wait(40)
        flow.checking = true
        var drift = flow.drift
        wait(80)
        compare(flow.drift, drift)
        compare(input.text, "synthetic")
    }
    function test_inactive_resets_visuals_without_touching_input() {
        input.text = "synthetic"
        flow.active = false
        compare(flow.startedAtMs, 0)
        compare(flow.drift, 0)
        compare(input.text, "synthetic")
    }
}
