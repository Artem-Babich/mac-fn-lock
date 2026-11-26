import AppKit
import Carbon.HIToolbox
import FnLockCore
import ServiceManagement

// Hold fn alone for ~1s to toggle between standard F1–F12 and media keys.
// Usage: fnlock            run the listener (needs Input Monitoring permission)
//        fnlock toggle     toggle once and exit
//        fnlock status     print the current mode

let holdSeconds = HoldSetting.seconds(environment: ProcessInfo.processInfo.environment["FNLOCK_HOLD_SECONDS"],
                                      saved: UserDefaults.standard.object(forKey: "holdSeconds") as? Double)
let bundleID = "rs.babich.fnlock"

func log(_ message: String) {
    FileHandle.standardError.write("[fnlock] \(message)\n".data(using: .utf8)!)
}

func modeName(_ standard: Bool) -> String { standard ? "F1–F12" : "media keys" }

func toggle() {
    let next = !(FnKeyMode.get() ?? false)
    let ok = FnKeyMode.set(next)
    log("toggled to \(modeName(next)) (applied=\(ok))")
    NSSound(named: next ? "Tink" : "Pop")?.play()
    MainActor.assumeIsolated { HUD.shared.show(standardKeys: next) } // always called on the main queue
    NotificationCenter.default.post(name: .fnLockToggled, object: nil)
}

switch CommandLine.arguments.dropFirst().first {
case "status":
    print(FnKeyMode.get().map(modeName) ?? "unknown")
    exit(0)
case "check-permission":
    // Internal: a fresh process sees a new Input Monitoring grant; the running listener does not.
    exit(CGPreflightListenEventAccess() ? 0 : 1)
default:
    break
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

switch CommandLine.arguments.dropFirst().first {
case "toggle":
    toggle()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { exit(0) } // let the sound and overlay finish
    app.run()
    exit(0)
default:
    break
}

// Started from Login Items or Finder there is no terminal: keep the log in ~/Library/Logs.
if isatty(STDERR_FILENO) == 0 {
    let logs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
    try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
    freopen(logs.appendingPathComponent("fnlock.log").path, "a", stderr)
}
let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
log("start pid=\(getpid()) version=\(version) parent=\(getppid()) path=\(Bundle.main.bundlePath)")

// One listener per user: a second one would toggle twice per hold.
let lockPath = FileManager.default.temporaryDirectory.appendingPathComponent("\(bundleID).lock").path
// A restarted copy (our own restart, or "Quit & Reopen") may start while the old one is still exiting.
guard let instanceLock = SingleInstanceLock(path: lockPath, waitSeconds: 5) else {
    log("another listener holds \(lockPath); exiting")
    print("FnLock is already running.")
    exit(0)
}
NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { _ in
    log("terminating (quit requested)")
}

// install.sh used to start FnLock with a LaunchAgent; stop those copies so only this one runs.
for label in LegacyLaunchAgents.remove(home: FileManager.default.homeDirectoryForCurrentUser) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = ["bootout", "gui/\(getuid())/\(label)"]
    try? p.run()
    p.waitUntilExit()
    log("removed old LaunchAgent \(label)")
}

let registeredKey = "loginItemRegistered"
let runningFromApp = Bundle.main.bundleURL.pathExtension == "app"
if LoginItemPolicy.shouldRegister(runningFromAppBundle: runningFromApp,
                                  alreadyRegisteredOnce: UserDefaults.standard.bool(forKey: registeredKey)) {
    do {
        try SMAppService.mainApp.register()
        UserDefaults.standard.set(true, forKey: registeredKey)
        log("added to Login Items")
    } catch {
        log("could not add to Login Items: \(error.localizedDescription)")
    }
}

final class Listener {
    var detector = FnHoldDetector(threshold: holdSeconds)
    var fnIsDown = false
    var tap: CFMachPort?

    func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged where event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Function):
            let down = event.flags.contains(.maskSecondaryFn)
            guard down != fnIsDown else { return }
            fnIsDown = down
            if down {
                detector.fnDown(at: ProcessInfo.processInfo.systemUptime)
                DispatchQueue.main.asyncAfter(deadline: .now() + holdSeconds) { [self] in
                    if detector.tick(at: ProcessInfo.processInfo.systemUptime) { toggle() }
                }
            } else {
                detector.fnUp()
            }
        default:
            detector.otherInput()
        }
    }
}

let listener = Listener()
let mask: CGEventMask = [CGEventType.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
    .reduce(0) { $0 | (1 << $1.rawValue) } | (1 << 14) // 14 = NSSystemDefined (media keys)

func startTap() {
    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
        eventsOfInterest: mask,
        callback: { _, type, event, refcon in
            Unmanaged<Listener>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
            return Unmanaged.passUnretained(event)
        },
        userInfo: Unmanaged.passUnretained(listener).toOpaque()
    ) else {
        log("cannot create event tap")
        exit(1)
    }
    listener.tap = tap
    CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    log("listening; hold fn for \(holdSeconds)s to toggle (current: \(FnKeyMode.get().map(modeName) ?? "unknown"))")
}

/// A fresh process sees a new Input Monitoring grant; this one keeps its launch-time answer.
func permissionGrantedInFreshProcess() -> Bool {
    let p = Process()
    p.executableURL = Bundle.main.executableURL
    p.arguments = ["check-permission"]
    guard (try? p.run()) != nil else { return false }
    p.waitUntilExit()
    return p.terminationStatus == 0
}

/// Start a new copy and exit; the new copy waits for our lock, then creates its tap with the grant.
func relaunch() {
    log("input monitoring granted; restarting so macOS delivers key events")
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = ["-n", Bundle.main.bundlePath]
    try? p.run()
    exit(0)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let welcome: WelcomeWindowController

    init(inputMonitoring: Bool) {
        welcome = MainActor.assumeIsolated { WelcomeWindowController(inputMonitoring: inputMonitoring) }
    }

    /// Runs first on any quit ("Quit & Reopen" included), before AppKit closes windows.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated { welcome.appIsQuitting = true }
        return .terminateNow
    }

    /// FnLock has no menu bar icon: opening the app again brings the Welcome window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated { welcome.show() }
        return false
    }
}

// macOS never delivers keyboard events to a tap created before Input Monitoring was granted, and
// never tells this process about a later grant. So: tap now if allowed; otherwise watch from fresh
// processes and restart once it is allowed. The permission is only requested from the Welcome window.
var listenerStart = ListenerStart()
let granted = CGPreflightListenEventAccess()
log("input monitoring granted=\(granted)")
if listenerStart.check(permissionGranted: granted) {
    startTap()
} else {
    log("waiting for Input Monitoring permission: allow FnLock in System Settings → Privacy & Security → Input Monitoring")
    var checks = 0
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
        let nowGranted = permissionGrantedInFreshProcess()
        checks += 1
        if checks % 15 == 0 { log("still waiting: granted=\(nowGranted) after \(checks * 2)s") }
        if listenerStart.check(permissionGranted: nowGranted) {
            if runningFromApp { relaunch() } else { log("input monitoring granted; restart fnlock to start listening") }
        }
    }
}

let delegate = AppDelegate(inputMonitoring: granted)
app.delegate = delegate
if runningFromApp, Onboarding.shouldShowAtLaunch(
    completed: UserDefaults.standard.bool(forKey: WelcomeWindowController.completedKey), inputMonitoring: granted) {
    MainActor.assumeIsolated { delegate.welcome.show() }
}
withExtendedLifetime(instanceLock) { app.run() }
