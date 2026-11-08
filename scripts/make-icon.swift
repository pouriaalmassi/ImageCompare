import AppKit

// Run: swift scripts/make-icon.swift [AppIcon.appiconset directory]
let destination = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "ImageCompare/Assets.xcassets/AppIcon.appiconset"
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)

let burntOrange = NSColor(calibratedRed: 0.72, green: 0.28, blue: 0.10, alpha: 1)
let cream = NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.93, alpha: 1)
func rounded(_ rect: NSRect, _ radius: CGFloat, _ color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func mountain(_ points: [NSPoint], _ color: NSColor) {
    let path = NSBezierPath()
    path.move(to: points[0])
    for point in points.dropFirst() { path.line(to: point) }
    path.close()
    color.setFill()
    path.fill()
}

var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        rounded(NSRect(x: 32, y: 32, width: 960, height: 960), 210, burntOrange)

        // Offset backing image makes the pair visible even at Dock sizes.
        rounded(NSRect(x: 176, y: 330, width: 570, height: 460), 50,
            NSColor(calibratedRed: 0.91, green: 0.57, blue: 0.33, alpha: 1))
        rounded(NSRect(x: 254, y: 234, width: 594, height: 472), 50, cream)
        let picture = NSBezierPath(roundedRect: NSRect(x: 282, y: 262, width: 538, height: 416),
            xRadius: 25, yRadius: 25)
        NSGraphicsContext.saveGraphicsState()
        picture.addClip()
        rounded(NSRect(x: 282, y: 262, width: 538, height: 416), 0,
            NSColor(calibratedRed: 0.97, green: 0.78, blue: 0.59, alpha: 1))
        rounded(NSRect(x: 552, y: 262, width: 268, height: 416), 0,
            NSColor(calibratedRed: 0.98, green: 0.87, blue: 0.64, alpha: 1))
        cream.setFill()
        NSBezierPath(ovalIn: NSRect(x: 663, y: 554, width: 65, height: 65)).fill()
        mountain([NSPoint(x: 266, y: 262), NSPoint(x: 447, y: 543),
                  NSPoint(x: 633, y: 262)], burntOrange)
        mountain([NSPoint(x: 473, y: 262), NSPoint(x: 650, y: 490),
                  NSPoint(x: 843, y: 262)],
            NSColor(calibratedRed: 0.84, green: 0.43, blue: 0.20, alpha: 1))
        NSGraphicsContext.restoreGraphicsState()

        // The swipe control is the app's central gesture.
        rounded(NSRect(x: 539, y: 218, width: 24, height: 504), 12, cream)
        rounded(NSRect(x: 512, y: 704, width: 78, height: 25), 12, cream)
        rounded(NSRect(x: 512, y: 211, width: 78, height: 25), 12, cream)
        NSGraphicsContext.restoreGraphicsState()

        let suffix = scale == 2 ? "@2x" : ""
        let filename = "icon_\(size)x\(size)\(suffix).png"
        try bitmap.representation(using: .png, properties: [:])!.write(to:
            URL(fileURLWithPath: destination).appendingPathComponent(filename))
        images.append(["filename": filename, "idiom": "mac", "scale": "\(scale)x", "size": "\(size)x\(size)"])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: URL(fileURLWithPath: destination).appendingPathComponent("Contents.json"))
print("Generated all 10 macOS app icon assets in \(destination)")
