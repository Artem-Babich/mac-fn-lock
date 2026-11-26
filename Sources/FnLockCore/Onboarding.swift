import Foundation

public enum StepState: Equatable, Sendable { case locked, active, done }
public enum PermissionAction: Equatable, Sendable { case showSystemPrompt, openSystemSettings }

/// Welcome window checklist. Pure state: the app feeds it live statuses.
public struct Onboarding: Equatable, Sendable {
    public var inputMonitoring: Bool
    public var globeKeyDoesNothing: Bool
    public var triedToggle: Bool

    public init(inputMonitoring: Bool, globeKeyDoesNothing: Bool, triedToggle: Bool) {
        self.inputMonitoring = inputMonitoring
        self.globeKeyDoesNothing = globeKeyDoesNothing
        self.triedToggle = triedToggle
    }

    public var inputMonitoringStep: StepState { inputMonitoring ? .done : .active }
    public var globeKeyStep: StepState { !inputMonitoring ? .locked : globeKeyDoesNothing ? .done : .active }
    public var tryStep: StepState { !inputMonitoring ? .locked : triedToggle ? .done : .active }

    /// The macOS prompt has its own "Open System Settings"; opening it ourselves too piles up windows.
    public static func permissionAction(alreadyRequested: Bool) -> PermissionAction {
        alreadyRequested ? .openSystemSettings : .showSystemPrompt
    }

    public static func shouldShowAtLaunch(completed: Bool, inputMonitoring: Bool) -> Bool {
        !completed || !inputMonitoring
    }
}

/// System Settings → Keyboard → "Press 🌐 key to" (com.apple.HIToolbox AppleFnUsageType).
public enum GlobeKeySetting {
    public static func doesNothing(fnUsageType: Int?) -> Bool { fnUsageType == 0 }
}
