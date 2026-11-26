// User story: when the mode switches, I see a light overlay for about a second, like the macOS
// volume HUD, so I know which mode I am in without listening for the sound. It sits at the bottom
// centre of the screen I am working on and names the new mode in English.
import CoreGraphics
import Testing
@testable import FnLockCore

@Suite("Mode switch overlay")
struct ModeHUDTests {
    @Test("when the mode becomes standard function keys, the overlay reads F1–F12")
    func standardKeysLabel() {
        #expect(ModeHUD.content(standardKeys: true).title == "F1–F12")
    }

    @Test("when the mode becomes media keys, the overlay reads Media keys")
    func mediaKeysLabel() {
        #expect(ModeHUD.content(standardKeys: false).title == "Media keys")
    }

    @Test("each mode has its own icon")
    func distinctIcons() {
        #expect(ModeHUD.content(standardKeys: true).symbol != ModeHUD.content(standardKeys: false).symbol)
    }

    @Test("the overlay is centred horizontally near the bottom of the screen")
    func bottomCentre() {
        let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let frame = ModeHUD.frame(size: CGSize(width: 200, height: 200), in: screen)
        #expect(frame.midX == screen.midX)
        #expect(frame.minY == screen.minY + ModeHUD.bottomMargin)
    }

    @Test("on a secondary screen the overlay is placed on that screen")
    func secondaryScreen() {
        let screen = CGRect(x: 1440, y: -200, width: 1920, height: 1080)
        let frame = ModeHUD.frame(size: CGSize(width: 200, height: 200), in: screen)
        #expect(screen.contains(frame))
        #expect(frame.midX == screen.midX)
    }

    @Test("on a very short screen the overlay still fits inside it")
    func shortScreen() {
        let screen = CGRect(x: 0, y: 0, width: 800, height: 250)
        let frame = ModeHUD.frame(size: CGSize(width: 200, height: 200), in: screen)
        #expect(frame.size == CGSize(width: 200, height: 200))
        #expect(frame.midX == screen.midX)
        #expect(screen.contains(frame))
    }
}
