// User story: as a Mac user I hold the fn key for about a second to toggle "Fn Lock"
// (F1–F12 as standard keys vs. media keys). A short fn press, or fn used as a modifier
// together with another key (fn+arrow, fn+F5…), must never toggle the mode.
import Testing
@testable import FnLockCore

@Suite("Fn hold detection")
struct FnHoldDetectorTests {
    @Test("when fn is held alone for the threshold, the mode toggles")
    func holdAloneToggles() {
        var d = FnHoldDetector(threshold: 1.0)
        d.fnDown(at: 10.0)
        #expect(d.tick(at: 11.0) == true)
    }

    @Test("when fn is released before the threshold, nothing toggles")
    func shortPressDoesNotToggle() {
        var d = FnHoldDetector(threshold: 1.0)
        d.fnDown(at: 10.0)
        #expect(d.tick(at: 10.5) == false)
        d.fnUp()
        #expect(d.tick(at: 11.5) == false)
    }

    @Test("when another key is pressed while fn is held, the hold is cancelled")
    func otherKeyCancels() {
        var d = FnHoldDetector(threshold: 1.0)
        d.fnDown(at: 10.0)
        d.otherInput()
        #expect(d.tick(at: 12.0) == false)
    }

    @Test("a single long hold toggles only once")
    func longHoldTogglesOnce() {
        var d = FnHoldDetector(threshold: 1.0)
        d.fnDown(at: 10.0)
        #expect(d.tick(at: 11.0) == true)
        #expect(d.tick(at: 13.0) == false)
    }

    @Test("after releasing fn, the next long hold toggles again")
    func nextHoldTogglesAgain() {
        var d = FnHoldDetector(threshold: 1.0)
        d.fnDown(at: 10.0)
        _ = d.tick(at: 11.0)
        d.fnUp()
        d.fnDown(at: 20.0)
        #expect(d.tick(at: 21.0) == true)
    }

    @Test("a cancelled hold does not affect the next hold")
    func cancelResetsOnNextPress() {
        var d = FnHoldDetector(threshold: 1.0)
        d.fnDown(at: 10.0)
        d.otherInput()
        d.fnUp()
        d.fnDown(at: 20.0)
        #expect(d.tick(at: 21.0) == true)
    }

    @Test("other keys pressed while fn is up do not matter")
    func otherInputWhileUpIsIgnored() {
        var d = FnHoldDetector(threshold: 1.0)
        d.otherInput()
        d.fnDown(at: 10.0)
        #expect(d.tick(at: 11.0) == true)
    }
}
