/// Detects "fn held alone for `threshold` seconds". Time is injected so the logic is testable.
public struct FnHoldDetector {
    public let threshold: Double
    private var pressedAt: Double?
    private var cancelled = false
    private var fired = false

    public init(threshold: Double) {
        self.threshold = threshold
    }

    public mutating func fnDown(at time: Double) {
        pressedAt = time
        cancelled = false
        fired = false
    }

    public mutating func fnUp() {
        pressedAt = nil
    }

    /// Any other key or modifier while fn is down means fn is used as a modifier, not a toggle.
    public mutating func otherInput() {
        if pressedAt != nil { cancelled = true }
    }

    /// Returns true exactly once per qualifying hold.
    public mutating func tick(at time: Double) -> Bool {
        guard let start = pressedAt, !cancelled, !fired, time - start >= threshold else { return false }
        fired = true
        return true
    }
}
