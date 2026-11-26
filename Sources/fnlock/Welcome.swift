import AppKit
import FnLockCore
import SwiftUI

extension Notification.Name {
    static let fnLockToggled = Notification.Name("FnLockToggled")
}

/// Live statuses behind the Welcome checklist, re-read every second while the window is open.
/// Input Monitoring is fixed for the life of the process (macOS only reports a new grant to a new
/// process), so `inputMonitoring` comes from the launch check; the app restarts itself on a grant.
@MainActor
final class WelcomeModel: ObservableObject {
    @Published var inputMonitoring: Bool
    @Published var globeKeyDoesNothing = WelcomeModel.readGlobeKey()
    @Published var triedToggle = false
    @Published var standardKeys = FnKeyMode.get() ?? false
    @Published var permissionRequested = false

    var onboarding: Onboarding {
        Onboarding(inputMonitoring: inputMonitoring, globeKeyDoesNothing: globeKeyDoesNothing, triedToggle: triedToggle)
    }

    init(inputMonitoring: Bool) {
        self.inputMonitoring = inputMonitoring
        NotificationCenter.default.addObserver(forName: .fnLockToggled, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.triedToggle = true
                self?.refresh()
            }
        }
    }

    func refresh() {
        globeKeyDoesNothing = Self.readGlobeKey()
        standardKeys = FnKeyMode.get() ?? standardKeys
    }

    func requestInputMonitoring() {
        switch Onboarding.permissionAction(alreadyRequested: permissionRequested) {
        case .showSystemPrompt:
            CGRequestListenEventAccess() // adds FnLock to the list and shows the macOS prompt
        case .openSystemSettings:
            Self.open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        }
        permissionRequested = true
    }

    static func openKeyboardSettings() {
        open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    static func open(_ url: String) {
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }

    static func readGlobeKey() -> Bool {
        let domain = "com.apple.HIToolbox" as CFString
        CFPreferencesAppSynchronize(domain)
        let value = CFPreferencesCopyAppValue("AppleFnUsageType" as CFString, domain) as? Int
        return GlobeKeySetting.doesNothing(fnUsageType: value)
    }
}

@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    nonisolated static let completedKey = "onboardingCompleted"
    let model: WelcomeModel
    private var window: NSWindow?
    private var timer: Timer?

    var appIsQuitting = false

    init(inputMonitoring: Bool) {
        model = WelcomeModel(inputMonitoring: inputMonitoring)
        super.init()
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil,
                                               queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.appIsQuitting = true }
        }
    }

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 560, height: 560),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.title = "Welcome to FnLock"
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.contentViewController = NSHostingController(rootView: WelcomeView(
                model: model, onFinish: { [weak self] in self?.window?.performClose(nil) }))
            w.center()
            window = w
        }
        model.refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.refresh() }
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
        if Onboarding.closingFinishesSetup(appIsQuitting: appIsQuitting) {
            UserDefaults.standard.set(true, forKey: Self.completedKey)
            log("welcome closed by user: setup finished")
        } else {
            log("welcome closed because FnLock is quitting: setup not finished")
        }
    }
}

// MARK: view

private struct WelcomeView: View {
    @ObservedObject var model: WelcomeModel
    let onFinish: () -> Void

    /// The largest icon representation: applicationIconImage hands SwiftUI a small, blurry one.
    private static let appIcon: NSImage = {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icns = NSImage(contentsOf: url),
           let best = icns.representations.max(by: { $0.pixelsWide < $1.pixelsWide }),
           let cg = best.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return NSImage(cgImage: cg, size: NSSize(width: 192, height: 192))
        }
        return NSApp.applicationIconImage
    }()

    var body: some View {
        let o = model.onboarding
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                Image(nsImage: Self.appIcon).resizable().interpolation(.high).frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to FnLock").font(.system(size: 24, weight: .bold))
                    Text("Hold fn for a second to switch the top row between F1–F12 and media keys.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 0) {
                StepRow(number: 1, title: "Allow Input Monitoring",
                        hint: model.permissionRequested
                            ? "Click Open System Settings in the macOS prompt and switch on FnLock. If macOS offers Quit & Reopen, either button works: FnLock restarts by itself."
                            : "FnLock needs it to see the fn key. It only listens and never records what you type.",
                        state: o.inputMonitoringStep) {
                    Button(model.permissionRequested ? "Open System Settings" : "Allow…") {
                        model.requestInputMonitoring()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Divider()
                StepRow(number: 2, title: "Set “Press 🌐 key to” to “Do Nothing”",
                        hint: o.globeKeyStep == .locked ? "Available after step 1."
                            : "Recommended. Otherwise holding fn may also open dictation or the emoji picker.",
                        state: o.globeKeyStep) {
                    Button("Open Keyboard Settings") { WelcomeModel.openKeyboardSettings() }
                }
                Divider()
                StepRow(number: 3, title: "Try it",
                        hint: o.tryStep == .locked ? "Available after step 1."
                            : "Hold fn alone for about a second. Current mode: \(model.standardKeys ? "F1–F12" : "Media keys").",
                        state: o.tryStep) { EmptyView() }
            }
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.5)))

            Text("FnLock runs in the background and starts at login. To see this window again, open FnLock from Applications.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Done", action: onFinish)
                    .keyboardShortcut(.defaultAction)
                    .disabled(o.inputMonitoringStep != .done)
            }
        }
        .padding(28)
        .padding(.top, 8)
        .frame(width: 560)
    }
}

private struct StepRow<Action: View>: View {
    let number: Int
    let title: String
    let hint: String
    let state: StepState
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            badge.frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text(hint).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if state == .active { action() }
        }
        .padding(.vertical, 14)
        .opacity(state == .locked ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title). \(stateLabel). \(hint)")
    }

    private var stateLabel: String {
        switch state {
        case .locked: "Not available yet"
        case .active: "To do"
        case .done: "Done"
        }
    }

    @ViewBuilder private var badge: some View {
        switch state {
        case .done:
            Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(.green)
        case .active:
            Text("\(number)").font(.system(size: 14, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.accentColor))
                .foregroundStyle(.white)
        case .locked:
            Text("\(number)").font(.system(size: 14, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Circle().strokeBorder(.secondary))
                .foregroundStyle(.secondary)
        }
    }
}
