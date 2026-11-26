import Foundation

public enum LoginItemPolicy {
    /// Register once; afterwards the user's choice in System Settings → Login Items wins.
    public static func shouldRegister(runningFromAppBundle: Bool, alreadyRegisteredOnce: Bool) -> Bool {
        runningFromAppBundle && !alreadyRegisteredOnce
    }
}

/// LaunchAgents written by install.sh in earlier versions. The app now starts via Login Items.
public enum LegacyLaunchAgents {
    public static let labels = ["rs.babich.fnlock", "ai.fnlock"]

    /// Deletes the plists and returns the labels that existed, so the caller can stop them.
    public static func remove(home: URL) -> [String] {
        labels.filter { label in
            let plist = home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
            return (try? FileManager.default.removeItem(at: plist)) != nil
        }
    }
}

/// An exclusive flock held for the life of the object (the kernel drops it if the process dies).
public final class SingleInstanceLock {
    private let fd: Int32

    public init?(path: String) {
        fd = open(path, O_CREAT | O_RDWR, 0o600)
        // A failed init still runs deinit (all properties are set), which closes fd.
        guard fd >= 0, flock(fd, LOCK_EX | LOCK_NB) == 0 else { return nil }
    }

    deinit { if fd >= 0 { close(fd) } }
}

/// How long fn must be held: FNLOCK_HOLD_SECONDS, else `defaults … holdSeconds`, else 1 s.
public enum HoldSetting {
    public static func seconds(environment: String?, saved: Double?) -> Double {
        [environment.flatMap(Double.init), saved].compactMap { $0 }.first { $0 > 0 } ?? 1.0
    }
}
