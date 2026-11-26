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
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

switch CommandLine.arguments.dropFirst().first {
case "status":
    print(FnKeyMode.get().map(modeName) ?? "unknown")
    exit(0)
case "toggle":
    toggle()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { exit(0) } // let the sound and overlay finish
    app.run()
    exit(0)
default:
    break
}

// One listener per user: a second one would toggle twice per hold.
let lockPath = FileManager.default.temporaryDirectory.appendingPathComponent("\(bundleID).lock").path
guard let instanceLock = SingleInstanceLock(path: lockPath) else {
    print("FnLock is already running.")
    exit(0)
}

// Started from Login Items or Finder there is no terminal: keep the log in ~/Library/Logs.
if isatty(STDERR_FILENO) == 0 {
    let logs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
    try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
    freopen(logs.appendingPathComponent("fnlock.log").path, "a", stderr)
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

func startTap() -> Bool {
    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
        eventsOfInterest: mask,
        callback: { _, type, event, refcon in
            Unmanaged<Listener>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
            return Unmanaged.passUnretained(event)
        },
        userInfo: Unmanaged.passUnretained(listener).toOpaque()
    ) else { return false }
    listener.tap = tap
    CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    log("listening; hold fn for \(holdSeconds)s to toggle (current: \(FnKeyMode.get().map(modeName) ?? "unknown"))")
    return true
}

if !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }
if !startTap() {
    // Nothing restarts a Login Item, so wait here until the user allows Input Monitoring.
    log("waiting for Input Monitoring permission: allow FnLock in System Settings → Privacy & Security")
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { timer in
        if startTap() { timer.invalidate() }
    }
}
withExtendedLifetime(instanceLock) { app.run() }
