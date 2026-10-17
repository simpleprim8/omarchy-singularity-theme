import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property string omarchyPath: ""

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: home + "/.local/state"
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME")
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"
  readonly property string vortexStatePath: home + "/.cache/aether-vortex/current.json"
  readonly property string desktopCapturePath: Quickshell.env("XDG_RUNTIME_DIR") + "/aether-vortex/desktop.jpg"

  property bool lockRequested: false
  property bool screensaverMode: false
  property bool awaitWakeAfterTimeout: false
  property double passwordDeadlineMs: 0
  property bool pendingSessionLock: false
  property bool authenticatingPassword: false
  property bool authenticationAccepted: false
  property bool fingerprintAuthenticating: false
  property bool passwordPamConfigured: false
  property bool fingerprintConfigured: false
  property bool previewVisible: false
  property bool previewVortex: false
  property bool singularityTheme: false
  property bool previewSingularity: false
  property string previewPassword: ""
  property string previewFailure: ""
  property bool previewChecking: false
  property bool previewSucceeded: false
  property bool vortexActive: false
  property vector2d vortexCenter: Qt.vector2d(0.5, 0.5)
  property real vortexStartedAtMs: 0
  property real vortexSeed: 0.31
  property string desktopCaptureUrl: ""
  property string enteredPassword: ""
  property string pendingPassword: ""
  property string failureMessage: ""
  property int failedAttempts: 0
  property string backgroundPath: ""
  property int backgroundVersion: 0
  property string lastEvent: "init"
  property string lastEventAt: ""
  property bool strandedLock: false
  property bool strandedLockResolved: false

  readonly property bool locked: lockRequested || sessionLock.locked || sessionLock.secure
  readonly property bool authenticating: authenticatingPassword || fingerprintAuthenticating

  PasswordFlow {
    id: entryFlow
    active: root.singularityTheme && root.lockRequested && !root.screensaverMode && !root.awaitWakeAfterTimeout
    maskedCount: root.enteredPassword.length
    checking: root.authenticatingPassword
  }
  PasswordFlow {
    id: previewFlow
    active: root.previewVisible && root.previewSingularity
    maskedCount: root.previewPassword.length
    checking: root.previewChecking
  }

  function realScreenCount() {
    var screens = Quickshell.screens || []
    var count = 0

    for (var i = 0; i < screens.length; i++) {
      var screen = screens[i]
      if (screen && screen.name && screen.width > 0 && screen.height > 0) count += 1
    }

    return count
  }

  function hasRealScreen() {
    return realScreenCount() > 0
  }

  function queueSessionLock() {
    pendingSessionLock = true
    if (!sessionLockStabilizeTimer.running) logEvent("lock-pending: screen-stabilizing")
    sessionLockStabilizeTimer.restart()
    if (!pendingSessionLockTimer.running) pendingSessionLockTimer.start()
  }

  function requestSessionLock() {
    if (!lockRequested || sessionLock.locked || sessionLock.secure) return
    if (sessionLockStabilizeTimer.running) return

    if (!hasRealScreen()) {
      if (!pendingSessionLock || lastEvent !== "lock-pending: no-real-screen") logEvent("lock-pending: no-real-screen")
      pendingSessionLock = true
      if (!pendingSessionLockTimer.running) pendingSessionLockTimer.start()
      return
    }

    pendingSessionLock = false
    pendingSessionLockTimer.stop()
    sessionLock.locked = true
  }

  // ext-session-lock outlives its client, and a restart carries no lock over, so
  // a session locked this early is an orphan behind Hyprland's failsafe. Outputs
  // are often still absent here, so ask until the answer means something.
  function checkStrandedLock() {
    if (strandedLockResolved || strandedLockCheckProc.running) return

    // A lock this shell took is nobody's orphan.
    if (locked || lockRequested) {
      strandedLockResolved = true
      return
    }

    strandedLockCheckProc.running = true
  }

  function recoverStrandedLock() {
    if (!strandedLock || locked || !passwordPamConfigured) return

    strandedLock = false
    logEvent("lock-stranded: recovering")
    beginLock()
  }

  function refreshBackground() {
    if (!readlinkProc.running) readlinkProc.running = true
  }

  function refreshFingerprintStatus() {
    if (!fingerprintCheckProc.running) fingerprintCheckProc.running = true
  }

  function loadVortexState(raw) {
    try {
      var state = JSON.parse(String(raw || ""))
      var center = state.whiteCenter
      var started = Number(state.startedAtMs)
      var age = Date.now() - started
      if (!Array.isArray(center) || center.length !== 2 ||
          !isFinite(Number(center[0])) || !isFinite(Number(center[1])) ||
          !isFinite(started) || age < 0 || age > 1800000) {
        vortexActive = false
        return
      }
      vortexCenter = Qt.vector2d(Number(center[0]), Number(center[1]))
      vortexStartedAtMs = started
      vortexSeed = Number(state.seed) || 0.31
      vortexActive = true
    } catch (error) {
      vortexActive = false
    }
  }

  function logEvent(event) {
    lastEvent = event
    lastEventAt = new Date().toISOString()
    console.log("omarchy lock " + lastEventAt + " " + event)
  }

  function resetAuthenticationState() {
    unlockPresentationTimer.stop()
    authenticationAccepted = false
    enteredPassword = ""
    pendingPassword = ""
    failureMessage = ""
    failedAttempts = 0
    authenticatingPassword = false
    fingerprintAuthenticating = false
    fingerprintRetryTimer.stop()
    if (passwordPam.active) passwordPam.abort()
    if (fingerprintPam.active) fingerprintPam.abort()
  }

  function beginLock(showVortex) {
    if (!passwordPamConfigured) {
      logEvent("lock-denied: missing-pam")
      return false
    }

    previewVisible = false
    previewPassword = ""
    resetAuthenticationState()
    lockRequested = true
    if (showVortex) {
      vortexCenter = Qt.vector2d(0.25 + Math.random() * 0.5, 0.25 + Math.random() * 0.5)
      vortexSeed = Math.random()
      vortexStartedAtMs = Date.now() - 10000
      vortexActive = true
    } else {
      vortexStateFile.reload()
    }
    if (vortexActive) idleBlankTimer.stop()
    else armBlankTimer()
    logEvent("lock-requested")
    queueSessionLock()

    Qt.callLater(function() {
      root.refreshBackground()
      root.refreshFingerprintStatus()
    })

    return true
  }

  function beginScreensaver() {
    if (root.locked) return true
    if (!beginLock(true)) return false
    screensaverMode = true
    awaitWakeAfterTimeout = false
    vortexStartedAtMs = Date.now()
    desktopCaptureUrl = "file://" + desktopCapturePath + "?v=" + vortexStartedAtMs
    var idle = shell && shell.shellConfig && shell.shellConfig.idle ? shell.shellConfig.idle : ({})
    var screensaverSeconds = Number(idle.screensaver)
    var lockSeconds = Number(idle.lock)
    if (!isFinite(screensaverSeconds) || screensaverSeconds < 0) screensaverSeconds = 180
    if (!isFinite(lockSeconds) || lockSeconds < 0) lockSeconds = 900
    passwordDeadlineMs = Date.now() + Math.max(0, lockSeconds - screensaverSeconds) * 1000
    passwordDeadlineTimer.start()
    logEvent("screensaver-started")
    return true
  }

  function requirePassword() {
    if (!screensaverMode) return
    screensaverMode = false
    passwordDeadlineTimer.stop()
    awaitWakeAfterTimeout = true
    desktopCaptureUrl = ""
    vortexActive = false
    if (!desktopCleanupProcess.running) desktopCleanupProcess.running = true
    logEvent("screensaver-password-required")
    if (!lockSideEffects.running) lockSideEffects.running = true
    if (sessionLock.secure) startFingerprint()
    idleBlankTimer.stop()
    runBlank()
  }

  function dismissScreensaver() {
    if (screensaverMode && sessionLock.secure && Date.now() < passwordDeadlineMs) finishUnlock()
    else if (screensaverMode && Date.now() >= passwordDeadlineMs) requirePassword()
  }

  function finishUnlock() {
    if (!root.locked && !lockRequested) return

    lockRequested = false
    screensaverMode = false
    awaitWakeAfterTimeout = false
    passwordDeadlineMs = 0
    passwordDeadlineTimer.stop()
    desktopCaptureUrl = ""
    pendingSessionLock = false
    sessionLockStabilizeTimer.stop()
    pendingSessionLockTimer.stop()
    resetAuthenticationState()
    idleBlankTimer.stop()
    sessionLock.locked = false
    vortexActive = false
    if (!vortexCleanupProcess.running) vortexCleanupProcess.running = true
    if (!desktopCleanupProcess.running) desktopCleanupProcess.running = true
    logEvent("unlocked")
    runWake()
  }

  function armBlankTimer() {
    idleBlankTimer.armedAt = Date.now()
    idleBlankTimer.restart()
  }

  function runWake() {
    awaitWakeAfterTimeout = false
    if (!wakeProcess.running) wakeProcess.running = true
    if (lockRequested && !vortexActive) armBlankTimer()
  }

  function runBlank() {
    if (vortexActive) return
    if (!blankProcess.running) blankProcess.running = true
  }

  onVortexActiveChanged: {
    if (vortexActive) {
      idleBlankTimer.stop()
      if (lockRequested) runWake()
    }
  }

  function submitPassword(value) {
    var password = String(value || "")
    if (!lockRequested || authenticatingPassword || authenticationAccepted || password.length === 0) return

    runWake()
    pendingPassword = password
    failureMessage = ""
    authenticatingPassword = true
    enteredPassword = ""

    if (!passwordPam.start()) {
      handlePasswordFailure()
      return
    }

    Qt.callLater(respondToPasswordPrompt)
  }

  function respondToPasswordPrompt() {
    if (!authenticatingPassword || !passwordPam.active || !passwordPam.responseRequired) return
    passwordPam.respond(pendingPassword)
  }

  function handlePasswordFailure() {
    if (!lockRequested || authenticationAccepted) return

    authenticatingPassword = false
    enteredPassword = ""
    pendingPassword = ""
    failedAttempts += 1
    failureMessage = "Authentication failed (" + failedAttempts + ")"
    runWake()
  }

  function authenticationSucceeded() {
    if (!lockRequested || authenticationAccepted) return
    // Only a successful PAM result reaches here. Keep the compositor lock held
    // during this brief acknowledgement, then perform the existing unlock.
    if (!singularityTheme) { finishUnlock(); return }
    authenticationAccepted = true
    authenticatingPassword = false
    enteredPassword = ""
    pendingPassword = ""
    failureMessage = ""
    idleBlankTimer.stop()
    unlockPresentationTimer.restart()
  }

  Timer {
    id: unlockPresentationTimer
    interval: 850
    onTriggered: if (root.authenticationAccepted && root.lockRequested) root.finishUnlock()
  }

  function startFingerprint() {
    if (!lockRequested || screensaverMode || !sessionLock.secure || !fingerprintConfigured) return
    if (fingerprintPam.active || fingerprintAuthenticating) return

    fingerprintAuthenticating = true
    if (!fingerprintPam.start()) {
      fingerprintAuthenticating = false
    }
  }

  function handleFingerprintFinished(result) {
    fingerprintAuthenticating = false

    if (!lockRequested) return
    if (result === PamResult.Success) {
      authenticationSucceeded()
    } else if (fingerprintConfigured) {
      fingerprintRetryTimer.restart()
    }
  }

  WlSessionLock {
    id: sessionLock

    locked: false

    onSecureStateChanged: {
      root.logEvent("secure=" + secure)
      if (secure) {
        root.pendingSessionLock = false
        sessionLockStabilizeTimer.stop()
        pendingSessionLockTimer.stop()
        if (root.screensaverMode) lockView.forceActiveFocus()
        else root.startFingerprint()
      }
    }

    onLockStateChanged: {
      root.logEvent("session-locked=" + locked)

      if (locked) {
        root.pendingSessionLock = false
        sessionLockStabilizeTimer.stop()
        pendingSessionLockTimer.stop()
      }

      if (!locked && root.lockRequested) {
        root.lockRequested = false
        root.screensaverMode = false
        root.awaitWakeAfterTimeout = false
        root.passwordDeadlineMs = 0
        passwordDeadlineTimer.stop()
        root.pendingSessionLock = false
        sessionLockStabilizeTimer.stop()
        pendingSessionLockTimer.stop()
        root.resetAuthenticationState()
        root.runWake()
      }
    }

    WlSessionLockSurface {
      id: lockSurface
      color: Color.background

      LockView {
        id: lockView
        anchors.fill: parent
        singularityActive: root.singularityTheme
        backgroundPath: root.backgroundPath
        backgroundVersion: root.backgroundVersion
        fingerprintConfigured: root.fingerprintConfigured
        authenticatingPassword: root.authenticatingPassword
        authenticationAccepted: root.authenticationAccepted
        entryDrift: entryFlow.drift
        failureMessage: root.failureMessage
        failedAttempts: root.failedAttempts
        inputEnabled: root.lockRequested && !root.screensaverMode && !root.authenticationAccepted
        screensaverMode: root.screensaverMode
        awaitWakeAfterTimeout: root.awaitWakeAfterTimeout
        loadBackground: root.locked
        vortexActive: root.vortexActive
        vortexCenter: root.vortexCenter
        vortexStartedAtMs: root.vortexStartedAtMs
        vortexSeed: root.vortexSeed
        desktopCaptureUrl: root.desktopCaptureUrl
        passwordText: root.enteredPassword
        onPasswordTextEdited: function(password) { root.enteredPassword = password }
        onSubmitPassword: function(password) { root.submitPassword(password) }
        onClearFailureRequested: root.failureMessage = ""
        onWakeRequested: root.runWake()
        onDismissScreensaverRequested: root.dismissScreensaver()
      }

    }
  }

  PanelWindow {
    id: previewWindow
    visible: root.previewVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-lock-preview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    LockView {
      anchors.fill: parent
      singularityActive: root.previewSingularity || root.singularityTheme
      backgroundPath: root.backgroundPath
      backgroundVersion: root.backgroundVersion
      fingerprintConfigured: root.fingerprintConfigured
      authenticatingPassword: root.previewChecking
      authenticationAccepted: root.previewSucceeded
      entryDrift: previewFlow.drift
      failureMessage: root.previewFailure
      failedAttempts: 0
      inputEnabled: root.previewSingularity && !root.previewChecking && !root.previewSucceeded
      loadBackground: root.previewVisible
      vortexActive: root.previewVisible && root.previewVortex
      vortexCenter: root.vortexCenter
      vortexStartedAtMs: root.vortexStartedAtMs
      vortexSeed: root.vortexSeed
      passwordText: root.previewPassword
      onPasswordTextEdited: function(password) { root.previewPassword = password; if (password.length) root.previewFailure = "" }
      onSubmitPassword: function(password) { root.previewPassword = "" }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      enabled: !root.previewSingularity
      onClicked: root.previewVisible = false
    }
  }

  FileView {
    path: root.stateHome + "/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: root.singularityTheme = String(text()).trim() === "singularity"
    onFileChanged: reload()
  }

  Timer {
    id: previewTimeout
    interval: 60000
    onTriggered: { root.previewVisible = false; root.previewSingularity = false; root.previewPassword = "" }
  }

  PamContext {
    id: passwordPam
    config: "omarchy-lock-password"
    user: root.userName

    onResponseRequiredChanged: root.respondToPasswordPrompt()
    onPamMessage: root.respondToPasswordPrompt()

    onCompleted: function(result) {
      root.authenticatingPassword = false
      root.pendingPassword = ""

      if (!root.lockRequested) return
      if (result === PamResult.Success) root.authenticationSucceeded()
      else root.handlePasswordFailure()
    }

    onError: function(error) {
      root.handlePasswordFailure()
    }
  }

  PamContext {
    id: fingerprintPam
    config: "omarchy-lock-fingerprint"
    user: root.userName

    onCompleted: function(result) {
      root.handleFingerprintFinished(result)
    }

    onError: function(error) {
      root.fingerprintAuthenticating = false
      if (root.lockRequested && root.fingerprintConfigured) fingerprintRetryTimer.restart()
    }
  }

  Timer {
    id: passwordDeadlineTimer
    interval: 1000
    repeat: true
    onTriggered: if (root.screensaverMode && Date.now() >= root.passwordDeadlineMs) root.requirePassword()
  }

  Process {
    id: lockSideEffects
    command: ["bash", "-c", "omarchy-system-lock"]
  }

  Timer {
    id: fingerprintRetryTimer
    interval: 250
    repeat: false
    onTriggered: root.startFingerprint()
  }

  Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = String(text || "").trim()
        if (next !== root.backgroundPath) {
          root.backgroundPath = next
          root.backgroundVersion += 1
        }
      }
    }
  }

  Process {
    id: fingerprintCheckProc
    command: ["bash", "-c", "if [[ -f /etc/pam.d/omarchy-lock-fingerprint ]] && command -v fprintd-list >/dev/null 2>&1 && fprintd-list \"$USER\" 2>/dev/null | grep -qi finger; then echo yes; else echo no; fi"]
    stdout: StdioCollector { id: fingerprintCheckStdout; waitForEnd: true }
    onExited: {
      root.fingerprintConfigured = String(fingerprintCheckStdout.text || "").trim() === "yes"
      if (root.lockRequested && root.fingerprintConfigured) root.startFingerprint()
      else if (!root.fingerprintConfigured && fingerprintPam.active) fingerprintPam.abort()
    }
  }

  Process {
    id: strandedLockCheckProc
    command: ["bash", "-c", "omarchy-hyprland-session-locked"]
    onExited: function(exitCode) {
      // No output to read the lock off yet.
      if (exitCode === 2) return

      root.strandedLockResolved = true

      // A lock taken while this was in flight is this shell's own.
      root.strandedLock = exitCode === 0 && !root.locked && !root.lockRequested
      root.recoverStrandedLock()
    }
  }

  Process {
    id: wakeProcess
    command: ["bash", "-c", "omarchy-system-wake"]
  }

  Process {
    id: vortexCleanupProcess
    command: ["rm", "-f", root.vortexStatePath]
  }

  Process {
    id: desktopCleanupProcess
    command: ["rm", "-f", root.desktopCapturePath]
  }

  FileView {
    id: vortexStateFile
    path: root.vortexStatePath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadVortexState(text())
    onFileChanged: reload()
    onLoadFailed: root.vortexActive = false
  }

  Process {
    id: blankProcess
    command: ["bash", "-c", "omarchy-brightness-keyboard off; omarchy-brightness-display off"]
  }

  Timer {
    id: idleBlankTimer
    interval: 5000
    repeat: false
    property double armedAt: 0
    onTriggered: {
      // A countdown frozen by suspend fires right after resume, which would
      // blank the freshly woken unlock screen under the user. Wall-clock time
      // exposes the gap: take a fresh run-up instead of blanking.
      if (Date.now() - armedAt > interval + 2000) {
        root.armBlankTimer()
        return
      }
      // Only a password check in flight should hold the display up. The
      // fingerprint PAM stays armed for the whole lock, so gating on
      // `authenticating` here would keep the panel lit until unlock.
      if (root.lockRequested && !root.authenticatingPassword && !root.vortexActive) root.runBlank()
    }
  }

  Timer {
    id: sessionLockStabilizeTimer
    interval: 500
    repeat: false
    onTriggered: root.requestSessionLock()
  }

  Timer {
    id: pendingSessionLockTimer
    interval: 100
    repeat: true
    onTriggered: root.requestSessionLock()
  }

  Timer {
    id: strandedLockRetryTimer
    interval: 500
    repeat: true
    // Covers the compositor settling; screens coming back re-arm it.
    readonly property int budget: 20
    property int remaining: 20
    running: !root.strandedLockResolved && remaining > 0

    function rearm() {
      if (!root.strandedLockResolved) remaining = budget
    }

    onTriggered: {
      remaining -= 1
      root.checkStrandedLock()
    }
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      root.requestSessionLock()

      // A monitor still coming up has no workspace, so cannot answer yet.
      strandedLockRetryTimer.rearm()
      root.checkStrandedLock()
    }
  }

  onAuthenticatingPasswordChanged: {
    if (!lockRequested) return
    if (authenticatingPassword) idleBlankTimer.stop()
    else if (!vortexActive) armBlankTimer()
  }

  FileView {
    path: "/etc/pam.d/omarchy-lock-password"
    watchChanges: true
    printErrors: false
    onLoaded: root.passwordPamConfigured = true
    onLoadFailed: root.passwordPamConfigured = false
    onFileChanged: reload()
  }

  // No lock before PAM is known good. An answer from before then may be stale --
  // the failsafe can be cleared from a TTY -- so re-ask rather than act on it.
  onPasswordPamConfiguredChanged: {
    if (!passwordPamConfigured) return

    strandedLock = false
    strandedLockResolved = false
    strandedLockRetryTimer.rearm()
    checkStrandedLock()
  }

  Component.onCompleted: {
    refreshBackground()
    refreshFingerprintStatus()
    checkStrandedLock()
  }

  IpcHandler {
    target: "lock"

    function lock(): string {
      if (!root.passwordPamConfigured) return "missing-pam"
      if (root.screensaverMode) root.requirePassword()
      if (!root.locked && !root.beginLock()) return "failed"
      return "ok"
    }

    function lockVortex(): string {
      if (!root.passwordPamConfigured) return "missing-pam"
      if (root.screensaverMode) root.requirePassword()
      if (!root.locked && !root.beginLock(true)) return "failed"
      return "ok"
    }

    function screensaverVortex(): string {
      return root.beginScreensaver() ? "ok" : "failed"
    }

    function isLocked(): string {
      return root.locked ? "true" : "false"
    }

    function status(): string {
      return JSON.stringify({
        locked: root.locked,
        requested: root.lockRequested,
        pending: root.pendingSessionLock,
        sessionLocked: sessionLock.locked,
        secure: sessionLock.secure,
        realScreens: root.realScreenCount(),
        passwordPam: root.passwordPamConfigured,
        fingerprint: root.fingerprintConfigured,
        authenticating: root.authenticating,
        vortex: root.vortexActive,
        singularity: root.singularityTheme,
        screensaverMode: root.screensaverMode,
        passwordDeadlineMs: root.passwordDeadlineMs,
        lastEvent: root.lastEvent,
        lastEventAt: root.lastEventAt
      })
    }

    function preview(): string {
      if (root.locked) return "locked"
      root.refreshBackground()
      root.refreshFingerprintStatus()
      root.previewVortex = false
      root.previewVisible = true
      return "ok"
    }

    function previewVortex(): string {
      if (root.locked) return "locked"
      root.vortexCenter = Qt.vector2d(0.61, 0.49)
      root.vortexStartedAtMs = Date.now() - 22000
      root.vortexSeed = 0.31
      root.previewVortex = true
      root.previewVisible = true
      return "ok"
    }

    function previewSingularity(count: int): string {
      if (root.locked) return "locked"
      root.previewChecking = false
      root.previewSucceeded = false
      root.previewFailure = ""
      root.previewPassword = "x".repeat(Math.max(0, Math.min(count, 128)))
      previewTimeout.restart()
      root.previewSingularity = true
      root.previewVisible = true
      return "ok"
    }

    function previewHud(state: string): string {
      if (root.locked) return "locked"
      root.previewChecking = state === "checking"
      root.previewSucceeded = state === "success"
      root.previewFailure = state === "failed" ? "Credentials not accepted. Type again." : ""
      root.previewPassword = ""
      root.previewSingularity = true
      root.previewVisible = true
      previewTimeout.restart()
      return "ok"
    }

    function hidePreview(): string {
      root.previewVisible = false
      root.previewVortex = false
      root.previewSingularity = false
      root.previewPassword = ""
      root.previewChecking = false
      root.previewSucceeded = false
      return "ok"
    }
  }
}
