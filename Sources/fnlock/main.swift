import AppKit
import Carbon.HIToolbox
import FnLockCore

// Hold fn alone for ~1s to toggle between standard F1–F12 and media keys.
// Usage: fnlock            run the listener (needs Input Monitoring permission)
//        fnlock toggle     toggle once and exit
//        fnlock status     print the current mode

let holdSeconds = Double(ProcessInfo.processInfo.environment["FNLOCK_HOLD_SECONDS"] ?? "") ?? 1.0

func log(_ message: String) {
    FileHandle.standardError.write("[fnlock] \(message)\n".data(using: .utf8)!)
}

func modeName(_ standard: Bool) -> String { standard ? "F1–F12" : "media keys" }

func toggle() {
    let next = !(FnKeyMode.get() ?? false)
    let ok = FnKeyMode.set(next)
    log("toggled to \(modeName(next)) (applied=\(ok))")
    NSSound(named: next ? "Tink" : "Pop")?.play()
}

switch CommandLine.arguments.dropFirst().first {
case "status":
    print(FnKeyMode.get().map(modeName) ?? "unknown")
    exit(0)
case "toggle":
    toggle()
    Thread.sleep(forTimeInterval: 0.3) // let the sound play
    exit(0)
default:
    break
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

if !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
    eventsOfInterest: mask,
    callback: { _, type, event, refcon in
        Unmanaged<Listener>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
        return Unmanaged.passUnretained(event)
    },
    userInfo: Unmanaged.passUnretained(listener).toOpaque()
) else {
    log("cannot create event tap: grant Input Monitoring to this binary in System Settings → Privacy & Security")
    exit(1)
}
listener.tap = tap
CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
log("input monitoring granted=\(CGPreflightListenEventAccess()); listening; hold fn for \(holdSeconds)s to toggle (current: \(FnKeyMode.get().map(modeName) ?? "unknown"))")
CFRunLoopRun()
