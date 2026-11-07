import Foundation
import IOKit
import IOKit.hidsystem

/// "Use F1, F2, etc. keys as standard function keys": true = standard F-keys, false = media keys.
/// IOHIDGet/SetParameter are deprecated, but no public replacement exists for HIDFKeyMode.
public enum FnKeyMode {
    private static let parameterKey = "HIDFKeyMode" as CFString
    private static let preferenceKey = "com.apple.keyboard.fnState" as CFString

    public static func get() -> Bool? {
        withConnection { conn in
            var value: UInt32 = 0
            var size: IOByteCount = 0
            let kr = IOHIDGetParameter(conn, parameterKey, IOByteCount(MemoryLayout<UInt32>.size), &value, &size)
            return kr == KERN_SUCCESS ? value != 0 : nil
        } ?? nil
    }

    @discardableResult
    public static func set(_ standard: Bool) -> Bool {
        let applied = withConnection { conn in
            var value: UInt32 = standard ? 1 : 0
            return IOHIDSetParameter(conn, parameterKey, &value, IOByteCount(MemoryLayout<UInt32>.size)) == KERN_SUCCESS
        } ?? false
        // Keep System Settings checkbox in sync and persist across reboots.
        CFPreferencesSetValue(preferenceKey, standard as CFBoolean, kCFPreferencesAnyApplication,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return applied
    }

    private static func withConnection<T>(_ body: (io_connect_t) -> T) -> T? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &conn) == KERN_SUCCESS else { return nil }
        defer { IOServiceClose(conn) }
        return body(conn)
    }
}
