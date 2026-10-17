import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property bool authenticationAccepted: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool screensaverMode: false
  property bool awaitWakeAfterTimeout: false
  property bool loadBackground: true
  property bool singularityActive: false
  property int submittedMaskCount: 0
  property real entryDrift: 0
  property bool vortexActive: false
  property vector2d vortexCenter: Qt.vector2d(0.5, 0.5)
  property real vortexStartedAtMs: 0
  property real vortexSeed: 0.31
  property string desktopCaptureUrl: ""
  property bool promptVisible: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()
  signal dismissScreensaverRequested()

  focus: screensaverMode || awaitWakeAfterTimeout
  Keys.onPressed: function(event) {
    if (root.screensaverMode || root.awaitWakeAfterTimeout) {
      if (root.screensaverMode) root.dismissScreensaverRequested()
      else root.wakeRequested()
      event.accepted = true
    }
  }
  onScreensaverModeChanged: if (screensaverMode) Qt.callLater(forceActiveFocus)
  onAwaitWakeAfterTimeoutChanged: if (awaitWakeAfterTimeout) Qt.callLater(forceActiveFocus)

  // Cache-busts the lock background by appending `?v=`. Adding a query
  // string keeps Image's loader happy while forcing it to reload when the
  // user picks a new background mid-session.
  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function revealPrompt() {
    if (!vortexActive) return
    promptVisible = true
    if (passwordText.length === 0 && !authenticatingPassword && failureMessage.length === 0)
      promptFadeTimer.restart()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: {
    syncPasswordText()
    if (passwordText.length > 0) {
      promptVisible = true
      promptFadeTimer.stop()
    } else if (vortexActive) {
      promptFadeTimer.restart()
    }
  }
  onVortexActiveChanged: {
    promptVisible = true
    if (vortexActive) promptFadeTimer.restart()
    else promptFadeTimer.stop()
  }
  onFailureMessageChanged: if (failureMessage.length > 0) revealPrompt()
  onAuthenticatingPasswordChanged: if (authenticatingPassword) revealPrompt()
  onInputEnabledChanged: {
    if (inputEnabled) {
      Qt.callLater(forcePasswordFocus)
      revealPrompt()
    }
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
    if (vortexActive) promptFadeTimer.restart()
  }

  Timer {
    id: promptFadeTimer
    interval: 6000
    repeat: false
    onTriggered: {
      if (root.vortexActive && root.passwordText.length === 0 &&
          !root.authenticatingPassword && root.failureMessage.length === 0)
        root.promptVisible = false
    }
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: root.awaitWakeAfterTimeout ? "black" : Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      visible: !root.singularityActive && !root.vortexActive && !root.awaitWakeAfterTimeout
      source: root.loadBackground && !root.vortexActive ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      visible: !root.singularityActive && !root.vortexActive && !root.awaitWakeAfterTimeout
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    AetherVortex {
      anchors.fill: parent
      visible: !root.singularityActive && root.vortexActive && !root.screensaverMode && !root.awaitWakeAfterTimeout && root.loadBackground
      center: root.vortexCenter
      startedAtMs: root.vortexStartedAtMs
      seed: root.vortexSeed
    }

    DrainToWormhole {
      anchors.fill: parent
      visible: root.vortexActive && root.screensaverMode && !root.awaitWakeAfterTimeout && root.loadBackground
      center: root.vortexCenter
      startedAtMs: root.vortexStartedAtMs
      seed: root.vortexSeed
      desktopCaptureUrl: root.desktopCaptureUrl
    }

    SingularityScene {
      anchors.fill: parent
      visible: root.singularityActive && !root.screensaverMode && !root.awaitWakeAfterTimeout
      animate: visible && root.loadBackground
      maskedCount: root.authenticatingPassword ? root.submittedMaskCount : root.passwordText.length
      checking: root.authenticatingPassword
      succeeded: root.authenticationAccepted
      contextLabel: "SESSION LOCK // OMARCHY"
      entryDrift: root.entryDrift
      failed: root.errorState
      message: root.errorState ? root.failureMessage : ""
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: {
        if (root.screensaverMode) root.dismissScreensaverRequested()
        else { root.wakeRequested(); root.revealPrompt(); root.forcePasswordFocus() }
      }
      onPositionChanged: {
        if (root.screensaverMode) root.dismissScreensaverRequested()
        else { root.wakeRequested(); root.revealPrompt() }
      }
    }

    BorderSurface {
      id: inputField
      visible: !root.screensaverMode && !root.awaitWakeAfterTimeout
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.singularityActive ? parent.height * 0.57 : (parent.height - height) / 2
      color: root.singularityActive ? "transparent" : Color.lock.background
      borderSpec: root.singularityActive ? Border.none() : root.inputBorderSpec
      radius: Style.cornerRadius
      clip: true
      opacity: !root.vortexActive || root.promptVisible || root.passwordText.length > 0 || root.authenticatingPassword || root.failureMessage.length > 0 ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        // Reserve the fingerprint icon's width on both sides so the centered
        // dots stay symmetric and never slide under the icon as they grow.
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        echoMode: TextInput.Password
        passwordCharacter: "\u25CF"
        passwordMaskDelay: 0
        color: root.singularityActive ? "transparent" : Color.lock.text
        selectionColor: root.singularityActive ? "transparent" : Color.lock.selection
        selectedTextColor: root.singularityActive ? "transparent" : Color.lock.text
        font.family: Style.font.family
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: !root.singularityActive && activeFocus && root.showPasswordCursor && text.length > 0
        cursorDelegate: Rectangle {
          width: 2
          color: Color.lock.text
          visible: !root.singularityActive && passwordInput.cursorVisible
        }

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
            root.revealPrompt()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }

        onAccepted: {
          root.submittedMaskCount = root.passwordText.length
          var submitted = root.passwordText
          if (submitted.length > 0) root.submitPassword(submitted)
        }

        Keys.onPressed: function(event) {
          root.wakeRequested()
          root.revealPrompt()
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: !root.singularityActive && passwordInput.text.length === 0
        color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      // Fingerprint hint pinned inside the field's right edge when a sensor is
      // enrolled, so the user knows they can touch to unlock instead of typing.
      // Matches hyprlock, which draws its fingerprint icon in the same spot.
      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: "󰈷"
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }

      HoverHandler {
        blocking: false
        onPointChanged: root.revealPrompt()
      }
    }
  }
}
