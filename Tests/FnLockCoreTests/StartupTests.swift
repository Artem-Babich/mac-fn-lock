// User story: I install FnLock with Homebrew or from the DMG and it just keeps working after a
// restart, without me setting anything up. If I turn it off in Login Items it stays off. If I had
// an older copy installed with install.sh, the two never run together and switch the mode twice.
import Foundation
import Testing
@testable import FnLockCore

@Suite("Start at login")
struct LoginItemPolicyTests {
    @Test("on the first launch from the app, FnLock adds itself to Login Items")
    func firstLaunchRegisters() {
        #expect(LoginItemPolicy.shouldRegister(runningFromAppBundle: true, alreadyRegisteredOnce: false))
    }

    @Test("after the user turns it off in Login Items, FnLock does not add itself again")
    func respectsUserChoice() {
        #expect(!LoginItemPolicy.shouldRegister(runningFromAppBundle: true, alreadyRegisteredOnce: true))
    }

    @Test("a bare binary run from a build folder never touches Login Items")
    func bareBinaryDoesNotRegister() {
        #expect(!LoginItemPolicy.shouldRegister(runningFromAppBundle: false, alreadyRegisteredOnce: false))
    }
}

@Suite("Old install.sh copies")
struct LegacyLaunchAgentsTests {
    func makeHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent("Library/LaunchAgents"), withIntermediateDirectories: true)
        return home
    }

    func agent(_ home: URL, _ name: String) -> URL {
        home.appendingPathComponent("Library/LaunchAgents/\(name).plist")
    }

    @Test("LaunchAgents left by older versions are removed and reported so they can be stopped")
    func removesOldAgents() throws {
        let home = try makeHome()
        for name in ["rs.babich.fnlock", "ai.fnlock"] {
            FileManager.default.createFile(atPath: agent(home, name).path, contents: Data())
        }
        let removed = LegacyLaunchAgents.remove(home: home)
        #expect(Set(removed) == ["rs.babich.fnlock", "ai.fnlock"])
        #expect(!FileManager.default.fileExists(atPath: agent(home, "rs.babich.fnlock").path))
        #expect(!FileManager.default.fileExists(atPath: agent(home, "ai.fnlock").path))
    }

    @Test("other apps' LaunchAgents are left alone")
    func keepsOtherAgents() throws {
        let home = try makeHome()
        FileManager.default.createFile(atPath: agent(home, "com.example.other").path, contents: Data())
        #expect(LegacyLaunchAgents.remove(home: home).isEmpty)
        #expect(FileManager.default.fileExists(atPath: agent(home, "com.example.other").path))
    }

    @Test("with no old copy installed, nothing is reported")
    func nothingToRemove() throws {
        #expect(LegacyLaunchAgents.remove(home: try makeHome()).isEmpty)
    }
}

@Suite("Single listener")
struct SingleInstanceLockTests {
    func lockPath() -> String {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).lock").path
    }

    @Test("while one listener runs, a second one cannot start")
    func secondInstanceRefused() {
        let path = lockPath()
        let first = SingleInstanceLock(path: path)
        #expect(first != nil)
        #expect(SingleInstanceLock(path: path) == nil)
        _ = first
    }

    @Test("after the first listener stops, a new one can start")
    func lockReleasedOnStop() {
        let path = lockPath()
        var first = SingleInstanceLock(path: path)
        #expect(first != nil)
        first = nil
        #expect(SingleInstanceLock(path: path) != nil)
    }
}

// User story: FnLock starts from Login Items, where I cannot set environment variables, so I change
// how long to hold fn with `defaults write rs.babich.fnlock holdSeconds 1.5`. The FNLOCK_HOLD_SECONDS
// variable still works when I run fnlock from a terminal, and wins over the saved setting.
@Suite("Hold duration setting")
struct HoldSettingTests {
    @Test("with nothing set, fn must be held for 1 second")
    func defaultIsOneSecond() {
        #expect(HoldSetting.seconds(environment: nil, saved: nil) == 1.0)
    }

    @Test("a duration saved with defaults write is used")
    func savedSettingUsed() {
        #expect(HoldSetting.seconds(environment: nil, saved: 1.5) == 1.5)
    }

    @Test("FNLOCK_HOLD_SECONDS wins over the saved setting")
    func environmentWins() {
        #expect(HoldSetting.seconds(environment: "0.7", saved: 1.5) == 0.7)
    }

    @Test("an unreadable or non-positive value falls back to the next source")
    func invalidValuesIgnored() {
        #expect(HoldSetting.seconds(environment: "abc", saved: 1.5) == 1.5)
        #expect(HoldSetting.seconds(environment: "0", saved: -2) == 1.0)
    }
}
