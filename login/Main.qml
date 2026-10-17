import QtQuick
import QtQuick.Controls as Controls
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1280; height: 720; color: "#020704"
    property string currentUser: userModel.lastUser || String(userModel.data(userModel.index(Math.max(0, userModel.lastIndex), 0), Qt.UserRole + 1) || "")
    property bool loginFailed: false
    property bool checking: false
    property bool authenticated: false
    property int submittedCount: 0
    property bool showOptions: false
    property int sessionIndex: {
        for (var i = 0; i < sessionModel.rowCount(); i++) {
            var name = String(sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "")
            if (name.indexOf("uwsm") !== -1) return i
        }
        return sessionModel.lastIndex
    }
    PasswordFlow {
        id: flow
        maskedCount: password.text.length
        checking: root.checking
    }
    SingularityScene {
        anchors.fill: parent
        maskedCount: root.checking ? root.submittedCount : password.text.length
        checking: root.checking
        entryDrift: flow.drift
        failed: root.loginFailed
        succeeded: root.authenticated
        contextLabel: "ACCOUNT // " + root.currentUser
        message: root.loginFailed ? "Password not accepted. Type again." : ""
    }
    TextInput {
        id: password
        objectName: "passwordInput"
        anchors.centerIn: parent
        width: 400; height: 80
        focus: true; enabled: !root.checking
        echoMode: TextInput.Password; passwordMaskDelay: 0
        inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        color: "transparent"; selectionColor: "transparent"; selectedTextColor: "transparent"
        cursorDelegate: Item {}
        onTextChanged: if (text.length) root.loginFailed = false
        onAccepted: {
            if (!text.length || root.checking) return
            root.submittedCount = text.length
            root.checking = true
            sddm.login(root.currentUser, text, root.sessionIndex)
            text = ""
        }
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape || (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier))) {
                text = ""; event.accepted = true
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: password.forceActiveFocus()
    }
    Row {
        visible: root.showOptions
        x: root.width * .66; y: root.height * .80
        spacing: 12
        Controls.ComboBox {
            palette.button: "#102019"; palette.buttonText: "#c9ddce"; palette.base: "#050b08"; palette.text: "#c9ddce"; palette.highlight: "#19412c"
            currentIndex: Math.max(0, userModel.lastIndex)
            width: 150; model: userModel; textRole: "name"
            displayText: root.currentUser
            onActivated: { root.currentUser = currentText; password.text = ""; password.forceActiveFocus() }
        }
        Controls.ComboBox {
            palette.button: "#102019"; palette.buttonText: "#c9ddce"; palette.base: "#050b08"; palette.text: "#c9ddce"; palette.highlight: "#19412c"
            width: 200; model: sessionModel; textRole: "name"
            currentIndex: root.sessionIndex
            onActivated: { root.sessionIndex = currentIndex; password.forceActiveFocus() }
        }
    }
    Row {
        visible: root.showOptions
        x: root.width * .66; y: root.height * .87
        spacing: 12
        Controls.Button { palette.button: "#102019"; palette.buttonText: "#c9ddce"; text: "Restart"; visible: sddm.canReboot; onClicked: sddm.reboot() }
        Controls.Button { palette.button: "#102019"; palette.buttonText: "#c9ddce"; text: "Power off"; visible: sddm.canPowerOff; onClicked: sddm.powerOff() }
    }
    Controls.Button {
        x: root.width * .92; y: root.height * .23
        width: 42; height: 30; text: "⋯"
        palette.button: "#102019"; palette.buttonText: "#c9ddce"
        Accessible.name: "Account, session and power options"
        onClicked: { root.showOptions = !root.showOptions; password.forceActiveFocus() }
    }
    Connections {
        target: sddm
        function onLoginFailed() { root.checking = false; root.authenticated = false; password.text = ""; root.loginFailed = true; Qt.callLater(password.forceActiveFocus) }
        function onLoginSucceeded() { root.authenticated = true; root.checking = true }
    }
    Component.onCompleted: password.forceActiveFocus()
}
