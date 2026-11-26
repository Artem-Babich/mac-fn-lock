// Draws the FnLock app icon (an "fn" keycap with a small lock) and writes resources/AppIcon.icns.
//   swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("FnLock-\(UUID().uuidString).iconset")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

/// Master artwork on a 1024 canvas (macOS template: 824 pt body, 100 pt margin).
func drawIcon() {
    let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, 0.30)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    color(0x2B3A67).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0x4A6FD8), ending: color(0x23305E))!.draw(in: body, angle: -90)

    // Keycap: darker base + lighter top face.
    let capBase = NSBezierPath(roundedRect: NSRect(x: 232, y: 222, width: 560, height: 560), xRadius: 96, yRadius: 96)
    color(0xC9CFDD).setFill()
    capBase.fill()
    let capTop = NSBezierPath(roundedRect: NSRect(x: 262, y: 272, width: 500, height: 490), xRadius: 78, yRadius: 78)
    NSGradient(starting: color(0xFFFFFF), ending: color(0xEDF0F6))!.draw(in: capTop, angle: -90)

    // "fn" label.
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 250, weight: .semibold),
        .foregroundColor: color(0x1E2747),
        .paragraphStyle: style,
    ]
    NSAttributedString(string: "fn", attributes: attrs).draw(in: NSRect(x: 262, y: 390, width: 500, height: 320))

    // Lock badge in the lower-right corner of the keycap.
    let badge = NSRect(x: 600, y: 196, width: 240, height: 240)
    color(0xFFB020).setFill()
    NSBezierPath(ovalIn: badge).fill()
    let config = NSImage.SymbolConfiguration(pointSize: 120, weight: .bold)
    if let lock = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let tinted = NSImage(size: lock.size, flipped: false) { rect in
            lock.draw(in: rect)
            NSColor.white.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        let s = tinted.size
        tinted.draw(in: NSRect(x: badge.midX - s.width / 2, y: badge.midY - s.height / 2, width: s.width, height: s.height))
    }
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let out = root.appendingPathComponent("resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try p.run()
p.waitUntilExit()
try? png(size: 1024).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("FnLock-icon-preview.png"))
try? FileManager.default.removeItem(at: iconset)
print(p.terminationStatus == 0 ? "wrote \(out.path)" : "iconutil failed")
