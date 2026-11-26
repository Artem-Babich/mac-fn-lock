import Foundation

public enum StepState: Equatable, Sendable { case locked, active, done }
public enum PermissionAction: Equatable, Sendable { case showSystemPrompt, openSystemSettings }

/// Welcome window checklist. Pure state: the app feeds it live statuses.
public struct Onboarding: Equatable, Sendable {
    public var inputMonitoring: Bool
    public var triedToggle: Bool

    public init(inputMonitoring: Bool, triedToggle: Bool) {
        self.inputMonitoring = inputMonitoring
        self.triedToggle = triedToggle
    }

    public var inputMonitoringStep: StepState { inputMonitoring ? .done : .active }
    public var tryStep: StepState { !inputMonitoring ? .locked : triedToggle ? .done : .active }

    /// The macOS prompt has its own "Open System Settings"; opening it ourselves too piles up windows.
    public static func permissionAction(alreadyRequested: Bool) -> PermissionAction {
        alreadyRequested ? .openSystemSettings : .showSystemPrompt
    }

    /// AppKit closes windows when the app quits ("Quit & Reopen", our own restart); that is not the user finishing.
    public static func closingFinishesSetup(appIsQuitting: Bool) -> Bool { !appIsQuitting }

    /// `wasOpenAtQuit`: the window was still open when FnLock quit or restarted (not closed by the user).
    public static func shouldShowAtLaunch(completed: Bool, inputMonitoring: Bool, wasOpenAtQuit: Bool = false) -> Bool {
        !completed || !inputMonitoring || wasOpenAtQuit
    }
}
