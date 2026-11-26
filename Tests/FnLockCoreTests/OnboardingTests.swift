// User story: the first time I open FnLock, a Welcome window walks me through setup one step at a
// time: allow Input Monitoring, then try a long press of fn. Each step ticks itself off as soon as it
// is done, without me clicking "check". FnLock has no menu bar icon, so opening the app again brings
// the window back. FnLock does not ask me to change what the 🌐 key does: a long press works with any
// "Press 🌐 key to" setting.
import Foundation
import Testing
@testable import FnLockCore

@Suite("Welcome window")
struct OnboardingTests {
    @Test("before Input Monitoring is allowed, only the permission step is active")
    func permissionFirst() {
        let o = Onboarding(inputMonitoring: false, triedToggle: false)
        #expect(o.inputMonitoringStep == .active)
        #expect(o.tryStep == .locked)
    }

    @Test("once Input Monitoring is allowed, the try step opens")
    func permissionUnlocksTry() {
        let o = Onboarding(inputMonitoring: true, triedToggle: false)
        #expect(o.inputMonitoringStep == .done)
        #expect(o.tryStep == .active)
    }

    @Test("after the first switch with fn, the try step is done")
    func tryDone() {
        let o = Onboarding(inputMonitoring: true, triedToggle: true)
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

// User story: after "Quit & Reopen" (or FnLock restarting itself) the Welcome window comes back,
// because I haven't finished setup. Only my own Done or close button finishes it.
@Suite("Finishing setup")
struct OnboardingCompletionTests {
    @Test("clicking Done or the close button finishes setup")
    func userCloseFinishes() {
        #expect(Onboarding.closingFinishesSetup(appIsQuitting: false))
    }

    @Test("the window closing because FnLock quits or restarts does not finish setup")
    func quitDoesNotFinish() {
        #expect(!Onboarding.closingFinishesSetup(appIsQuitting: true))
    }
}

// User story: I allow Input Monitoring while the Welcome window is open. FnLock restarts (by itself or
// via "Quit & Reopen") and the window comes back with step 1 ticked, so I see it worked and can try it,
// even if I had finished setup before (for example, permission was reset by an update).
@Suite("Welcome window after a restart")
struct WelcomeAfterRestartTests {
    @Test("if the window was open when FnLock restarted, it opens again")
    func reopensAfterRestart() {
        #expect(Onboarding.shouldShowAtLaunch(completed: true, inputMonitoring: true, wasOpenAtQuit: true))
    }

    @Test("if the user had closed the window, a restart does not bring it back")
    func staysClosedAfterUserClose() {
        #expect(!Onboarding.shouldShowAtLaunch(completed: true, inputMonitoring: true, wasOpenAtQuit: false))
    }
}
