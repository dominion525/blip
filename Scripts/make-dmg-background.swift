// Draws the background of the disk image window and writes it as a PNG.
// Usage: swift Scripts/make-dmg-background.swift <output PNG>
// The window is 660x400. The app icon sits on the left and the Applications drop link on the right;
// this draws the ground and the arrow between them. Keep the size in step with make-dmg.sh.

import AppKit
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write("usage: make-dmg-background.swift <output.png>\n".data(using: .utf8)!)
    exit(2)
}
let outputURL = URL(fileURLWithPath: arguments[1])

// Window size, and the icon centers make-dmg.sh passes to create-dmg. Finder measures y from the top
let width = 660
let height = 400
let iconY: CGFloat = 190
let appIconX: CGFloat = 165
let dropLinkX: CGFloat = 495

let ctx = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx.setShouldAntialias(true)

/// Finder places icons from the top; Core Graphics draws from the bottom
func flip(_ y: CGFloat) -> CGFloat { CGFloat(height) - y }

// 1. The ground, a shade lighter than the icon plate so the plated icon stays legible on it
ctx.setFillColor(CGColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

// 2. The arrow between the two icons, pointing at the Applications folder
let arrowColor = CGColor(red: 0.72, green: 0.72, blue: 0.75, alpha: 1)
let midX = (appIconX + dropLinkX) / 2
let arrowY = flip(iconY)
let shaftHalf: CGFloat = 46
let headLength: CGFloat = 26
let headHalfHeight: CGFloat = 20

ctx.setStrokeColor(arrowColor)
ctx.setLineWidth(7)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: midX - shaftHalf, y: arrowY))
ctx.addLine(to: CGPoint(x: midX + shaftHalf - headLength, y: arrowY))
ctx.strokePath()

ctx.setFillColor(arrowColor)
ctx.move(to: CGPoint(x: midX + shaftHalf, y: arrowY))
ctx.addLine(to: CGPoint(x: midX + shaftHalf - headLength, y: arrowY + headHalfHeight))
ctx.addLine(to: CGPoint(x: midX + shaftHalf - headLength, y: arrowY - headHalfHeight))
ctx.closePath()
ctx.fillPath()

// 3. Write the PNG
let image = ctx.makeImage()!
let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write("failed to write \(outputURL.path)\n".data(using: .utf8)!)
    exit(1)
}
