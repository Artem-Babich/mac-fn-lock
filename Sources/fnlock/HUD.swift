import AppKit
import FnLockCore

/// A volume-HUD-style overlay that names the new mode for about a second.
/// Never takes focus, ignores the mouse, shows on every Space and over full-screen apps.
@MainActor
final class HUD {
    static let shared = HUD()

    private let size = CGSize(width: 180, height: 180)
    private let visibleSeconds = 0.9
    private var generation = 0
    private lazy var panel: NSPanel = makePanel()
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")

    func show(standardKeys: Bool) {
        let content = ModeHUD.content(standardKeys: standardKeys)
        let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
        icon.image = NSImage(systemSymbolName: content.symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        label.stringValue = content.title

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let screen { panel.setFrame(ModeHUD.frame(size: size, in: screen.visibleFrame), display: false) }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        generation += 1
        let current = generation
        panel.orderFrontRegardless()
        fade(to: 1, duration: reduceMotion ? 0 : 0.15)
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: content.title, .priority: NSAccessibilityPriorityLevel.high.rawValue])

        DispatchQueue.main.asyncAfter(deadline: .now() + visibleSeconds) { [self] in
            guard current == generation else { return } // a newer toggle owns the panel
            fade(to: 0, duration: reduceMotion ? 0 : 0.3) { [self] in
                if current == generation { panel.orderOut(nil) }
            }
        }
    }

    private func fade(to alpha: CGFloat, duration: TimeInterval, done: (@MainActor () -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            panel.animator().alphaValue = alpha
        }, completionHandler: { MainActor.assumeIsolated { done?() } })
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.alphaValue = 0

        let blur = NSVisualEffectView(frame: CGRect(origin: .zero, size: size))
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 22
        blur.layer?.masksToBounds = true

        icon.contentTintColor = .labelColor
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .center
        let stack = NSStackView(views: [icon, label])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: blur.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: blur.centerYAnchor),
        ])
        panel.contentView = blur
        return panel
    }
}
