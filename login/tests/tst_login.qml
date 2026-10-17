import QtQuick
import QtTest
import ".."

TestCase {
    id: test
    name: "LoginRetry"
    when: windowShown
    property var loginView
    property string submitted: ""
    property int attempts: 0
    QtObject {
        id: userModel
        property string lastUser: "synthetic-user"
        property int lastIndex: 0
        function index(i, column) { return i }
        function data(i, role) { return "synthetic-user" }
    }
    QtObject {
        id: sessionModel
        property int lastIndex: 0
        function rowCount() { return 1 }
        function index(i, column) { return i }
        function data(i, role) { return "uwsm" }
    }
    QtObject {
        id: sddm
        property bool canReboot: false
        property bool canPowerOff: false
        signal loginFailed()
        signal loginSucceeded()
        function login(user, password, session) { test.submitted = password; test.attempts++ }
        function reboot() {}
        function powerOff() {}
    }
    Component { id: screen; Main {} }
    function init() {
        submitted = ""; attempts = 0
        loginView = screen.createObject(test)
        verify(loginView !== null)
    }
    function cleanup() { loginView.destroy() }
    function test_failed_attempt_accepts_fresh_password_without_ctrl_u() {
        var input = findChild(loginView, "passwordInput")
        verify(input !== null)
        input.text = "wrong-synthetic"
        input.accepted()
        compare(attempts, 1)
        compare(submitted, "wrong-synthetic")
        compare(input.text, "")
        verify(loginView.checking)
        sddm.loginFailed()
        verify(!loginView.checking)
        verify(loginView.loginFailed)
        compare(input.text, "")
        wait(10)
        input.text = "fresh-synthetic"
        verify(!loginView.loginFailed)
        input.accepted()
        compare(attempts, 2)
        compare(submitted, "fresh-synthetic")
        verify(!loginView.authenticated)
        sddm.loginSucceeded()
        verify(loginView.authenticated)
    }
}
