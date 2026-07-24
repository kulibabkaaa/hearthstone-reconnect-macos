import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: generate_icon.swift INPUT OUTPUT\n", stderr)
    exit(64)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = NSImage(contentsOf: inputURL) else {
    fputs("Could not read the icon source.\n", stderr)
    exit(66)
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Could not create the icon canvas.\n", stderr)
    exit(70)
}

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Could not create the icon graphics context.\n", stderr)
    exit(70)
}

NSGraphicsContext.current = context
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

let iconBounds = NSRect(x: 14, y: 14, width: 996, height: 996)
NSBezierPath(
    roundedRect: iconBounds,
    xRadius: 214,
    yRadius: 214
).addClip()

source.draw(
    in: NSRect(x: 0, y: 0, width: 1024, height: 1024),
    from: NSRect(origin: .zero, size: source.size),
    operation: .copy,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
)
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let data = bitmap.representation(
    using: .png,
    properties: [.compressionFactor: 0.9]
) else {
    fputs("Could not encode the icon.\n", stderr)
    exit(70)
}

do {
    try data.write(to: outputURL, options: .atomic)
} catch {
    fputs("Could not write the icon: \(error)\n", stderr)
    exit(74)
}
