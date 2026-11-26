import CoreGraphics

/// What the mode-switch overlay shows and where it goes. Drawing lives in the app target.
public enum ModeHUD {
    /// Distance from the bottom of the visible screen area, close to the system volume HUD.
    public static let bottomMargin: CGFloat = 140

    /// `symbol` is an SF Symbol name.
    public static func content(standardKeys: Bool) -> (title: String, symbol: String) {
        standardKeys ? ("F1–F12", "keyboard") : ("Media keys", "playpause")
    }

    /// `screen` is the visible frame of the target screen in global coordinates (origin bottom-left).
    public static func frame(size: CGSize, in screen: CGRect) -> CGRect {
        let y = min(screen.minY + bottomMargin, screen.maxY - size.height)
        return CGRect(x: screen.midX - size.width / 2, y: max(screen.minY, y), width: size.width, height: size.height)
    }
}
