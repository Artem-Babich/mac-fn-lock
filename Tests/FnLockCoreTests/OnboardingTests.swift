// User story: the first time I open FnLock, a Welcome window walks me through setup one step at a
// time: allow Input Monitoring, set "Press 🌐 key to" to "Do Nothing" (recommended), then try a long
// press of fn. Each step ticks itself off as soon as it is done, without me clicking "check".
// FnLock has no menu bar icon, so opening the app again brings the window back.
import Foundation
import Testing
@testable import FnLockCore

@Suite("Welcome window")
struct OnboardingTests {
    @Test("before Input Monitoring is allowed, only the permission step is active")
    func permissionFirst() {
        let o = Onboarding(inputMonitoring: false, globeKeyDoesNothing: false, triedToggle: false)
        #expect(o.inputMonitoringStep == .active)
        #expect(o.globeKeyStep == .locked)
        #expect(o.tryStep == .locked)
    }

    @Test("once Input Monitoring is allowed, the globe key and try steps open")
    func permissionUnlocksRest() {
        let o = Onboarding(inputMonitoring: true, globeKeyDoesNothing: false, triedToggle: false)
        #expect(o.inputMonitoringStep == .done)
        #expect(o.globeKeyStep == .active)
        #expect(o.tryStep == .active)
    }

    @Test("when the globe key is already set to Do Nothing, that step is done")
    func globeKeyDone() {
        let o = Onboarding(inputMonitoring: true, globeKeyDoesNothing: true, triedToggle: false)
        #expect(o.globeKeyStep == .done)
    }

    @Test("after the first switch with fn, the try step is done")
    func tryDone() {
        let o = Onboarding(inputMonitoring: true, globeKeyDoesNothing: false, triedToggle: true)
        #expect(o.tryStep == .done)
    }

    @Test("the window opens at launch until setup is finished once")
    func showsUntilCompleted() {
        #expect(Onboarding.shouldShowAtLaunch(completed: false, inputMonitoring: true))
        #expect(!Onboarding.shouldShowAtLaunch(completed: true, inputMonitoring: true))
    }

    @Test("the window opens at launch whenever Input Monitoring is missing, even after setup")
    func showsWithoutPermission() {
        #expect(Onboarding.shouldShowAtLaunch(completed: true, inputMonitoring: false))
    }
}

@Suite("Globe key setting")
struct GlobeKeySettingTests {
    @Test("Press 🌐 key to → Do Nothing is recognised")
    func doNothing() {
        #expect(GlobeKeySetting.doesNothing(fnUsageType: 0))
    }

    @Test("emoji, dictation or input source switching are not Do Nothing")
    func otherActions() {
        for value in [1, 2, 3] { #expect(!GlobeKeySetting.doesNothing(fnUsageType: value)) }
    }

    @Test("when the setting was never changed, it is not Do Nothing")
    func unset() {
        #expect(!GlobeKeySetting.doesNothing(fnUsageType: nil))
    }
}

// User story: after I allow Input Monitoring, FnLock restarts itself (or I click "Quit & Reopen").
// The new copy must not give up just because the old one is still shutting down.
@Suite("Restart hand-over")
struct LockHandOverTests {
    @Test("a new listener waits briefly for the old one to exit, then starts")
    func waitsForOldInstance() {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).lock").path
        var old = SingleInstanceLock(path: path)
        #expect(old != nil)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { old = nil }
        #expect(SingleInstanceLock(path: path, waitSeconds: 3) != nil)
    }

    @Test("if the old listener keeps running, the new one gives up after the wait")
    func givesUpWhenOldStays() {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).lock").path
        let old = SingleInstanceLock(path: path)
        #expect(old != nil)
        #expect(SingleInstanceLock(path: path, waitSeconds: 0.3) == nil)
        _ = old
    }
}

// User story: when I click Allow, I see only the macOS permission prompt; it has its own
// "Open System Settings" button. FnLock opens System Settings itself only if I click again
// (for example after closing or denying the prompt), so windows don't pile up.
@Suite("Allow button")
struct PermissionButtonTests {
    @Test("the first click shows only the macOS permission prompt")
    func firstClickPrompts() {
        #expect(Onboarding.permissionAction(alreadyRequested: false) == .showSystemPrompt)
    }

    @Test("a later click opens Input Monitoring in System Settings")
    func laterClickOpensSettings() {
        #expect(Onboarding.permissionAction(alreadyRequested: true) == .openSystemSettings)
    }
}
