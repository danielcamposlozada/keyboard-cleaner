// Renders the app icon (1024×1024 PNG) with AppKit.
// Usage: swift scripts/make-icon.swift <out.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon grid: 824pt body inset 100pt, corner radius ~185.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let path = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

// Soft drop shadow.
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.black.setFill()
path.fill()
NSGraphicsContext.restoreGraphicsState()

// Fresh teal → blue gradient.
NSGradient(colors: [
    NSColor(srgbRed: 0.16, green: 0.84, blue: 0.80, alpha: 1),
    NSColor(srgbRed: 0.10, green: 0.45, blue: 0.95, alpha: 1),
])!.draw(in: path, angle: -60)

func drawSymbol(_ name: String, pointSize: CGFloat, center: NSPoint, color: NSColor) {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        .applying(.init(paletteColors: [color]))
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return }
    let s = img.size
    img.draw(in: NSRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height))
}

drawSymbol("keyboard", pointSize: 430, center: NSPoint(x: 500, y: 450), color: .white)
drawSymbol("sparkles", pointSize: 190, center: NSPoint(x: 720, y: 720),
           color: NSColor(srgbRed: 1, green: 0.95, blue: 0.70, alpha: 1))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
