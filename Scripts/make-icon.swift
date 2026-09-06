// Draws the app icon artwork and writes it as a PNG.
// Usage: swift Scripts/make-icon.swift <output PNG> [size in pixels] [--dark] [--plate=RRGGBB]
// A monochrome line drawing of an original arrow cursor with seven rays.
// --plate=RRGGBB puts the drawing on a rounded square of that color, on the standard macOS icon grid (824 of 1024, corner radius 185).
// Without it the background stays transparent. --dark draws white strokes (for the About panel in dark mode).

import AppKit
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <output.png> [size] [--dark]\n".data(using: .utf8)!)
    exit(2)
}
let outputURL = URL(fileURLWithPath: arguments[1])
let isDark = arguments.contains("--dark")
let plateHex = arguments.first { $0.hasPrefix("--plate=") }.map { String($0.dropFirst("--plate=".count)) }
let size = arguments.dropFirst(2).compactMap { Int($0) }.first ?? 1024
let scale = CGFloat(size) / 1024

let ink = isDark
    ? CGColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
    : CGColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)

let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx.scaleBy(x: scale, y: scale)
ctx.setShouldAntialias(true)

// 1. The plate: a rounded square on the macOS icon grid, or nothing
if let hex = plateHex, let value = UInt32(hex, radix: 16) {
    let plate = CGColor(
        red: CGFloat((value >> 16) & 0xff) / 255,
        green: CGFloat((value >> 8) & 0xff) / 255,
        blue: CGFloat(value & 0xff) / 255,
        alpha: 1
    )
    let plateRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    ctx.setFillColor(plate)
    ctx.addPath(CGPath(roundedRect: plateRect, cornerWidth: 185, cornerHeight: 185, transform: nil))
    ctx.fillPath()
}

// 2. The drawing, defined in a 742x706 y-down space and scaled into the canvas
let glyphWidth: CGFloat = 742
let glyphHeight: CGFloat = 706
// The drawing fills 980 of the canvas without a plate and stays inside the plate with one
let glyphScale: CGFloat = (plateHex == nil ? 980 : 700) / glyphWidth
let originX = 512 - glyphWidth * glyphScale / 2
let originY = 512 + glyphHeight * glyphScale / 2
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: originX + x * glyphScale, y: originY - y * glyphScale)
}

ctx.setStrokeColor(ink)
ctx.setFillColor(ink)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

// Rotate the arrow and rays counterclockwise around the tip so the tail points toward 4 o'clock
let tip = p(352, 320)
let rotation: CGFloat = 20 * .pi / 180
ctx.translateBy(x: tip.x, y: tip.y)
ctx.rotate(by: rotation)
ctx.translateBy(x: -tip.x, y: -tip.y)

// Seven rays over the 240 degrees opposite the tail, 40 degrees apart, alternating long and short
let rayWidth: CGFloat = 46 * glyphScale
ctx.setLineWidth(rayWidth)
for index in 0..<7 {
    // 0 is right, counterclockwise: from right (0) to lower left (240)
    let angle = CGFloat(index) * 40 / 180 * .pi
    let inner: CGFloat = 150 * glyphScale
    let length: CGFloat = (index % 2 == 0 ? 100 : 70) * glyphScale
    let start = CGPoint(x: tip.x + cos(angle) * inner, y: tip.y + sin(angle) * inner)
    let end = CGPoint(x: tip.x + cos(angle) * (inner + length), y: tip.y + sin(angle) * (inner + length))
    ctx.move(to: start)
    ctx.addLine(to: end)
    ctx.strokePath()
}

// Arrow cursor with its own proportions: sharp tip, slightly wide wings, thin long tail, deep notch
let arrow: [CGPoint] = [
    p(352, 320),   // tip
    p(352, 600),   // bottom of the left edge
    p(420, 545),   // notch
    p(478, 680),   // tail, lower left
    p(526, 660),   // tail, lower right
    p(468, 526),   // tail root (right)
    p(556, 518),   // right wing
]
let arrowPath = CGMutablePath()
arrowPath.addLines(between: arrow)
arrowPath.closeSubpath()
ctx.setLineWidth(18 * glyphScale)
ctx.addPath(arrowPath)
ctx.strokePath()
ctx.addPath(arrowPath)
ctx.fillPath()

// 3. Write the PNG
let image = ctx.makeImage()!
let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write("failed to write \(outputURL.path)\n".data(using: .utf8)!)
    exit(1)
}
