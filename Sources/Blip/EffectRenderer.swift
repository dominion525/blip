// Effect drawing. OverlayView hands each renderer its bounds, the cursor position (nil when absent), and the time since the effect appeared.
// One type per effect; makeRenderer picks the one matching the stored setting.

import AppKit
import BlipCore

protocol EffectRenderer: AnyObject {
    /// Whether the drawing changes over time. When true, OverlayController requests redraws at 60 fps
    var isAnimated: Bool { get }
    /// `spot` is the cursor in view coordinates; nil means the cursor is on another screen
    func draw(in ctx: CGContext, bounds: CGRect, spot: CGPoint?, elapsed: TimeInterval)
}

/// Creates the renderer for the selected effect. Effects not implemented yet use Spotlight for now
func makeRenderer(for effect: Effect) -> EffectRenderer {
    switch effect {
    case .spotlight, .flash:
        return SpotlightRenderer()
    case .zoom:
        return ZoomRenderer()
    case .focusLines:
        return FocusLinesRenderer()
    }
}

// MARK: - Shared drawing

/// Dims the whole view, punches a hole of `radius` at `center`, and strokes the ring. Shared by Spotlight and Zoom
private func drawDimWithHole(in ctx: CGContext, bounds: CGRect, center: CGPoint?, radius: CGFloat) {
    ctx.setFillColor(NSColor.black.withAlphaComponent(Config.dimOpacity).cgColor)
    ctx.fill(bounds)

    guard let center = center else { return }
    let hole = Geometry.holeRect(center: center, radius: radius)

    // Punch the hole with the .clear blend mode (erase the dim so the desktop shows through)
    ctx.setBlendMode(.clear)
    ctx.fillEllipse(in: hole)

    // Back to .normal for the ring. Inset by half the line width so the stroke is centered on the hole's edge
    ctx.setBlendMode(.normal)
    ctx.setStrokeColor(Config.ringColor.cgColor)
    ctx.setLineWidth(Config.ringWidth)
    ctx.strokeEllipse(in: hole.insetBy(dx: Config.ringWidth / 2, dy: Config.ringWidth / 2))
}

// MARK: - Spotlight

/// Dims the screen and punches a ringed hole at the cursor
final class SpotlightRenderer: EffectRenderer {
    let isAnimated = false

    func draw(in ctx: CGContext, bounds: CGRect, spot: CGPoint?, elapsed: TimeInterval) {
        drawDimWithHole(in: ctx, bounds: bounds, center: spot, radius: Config.spotRadius)
    }
}

// MARK: - Zoom

/// A hole as large as the screen shrinks onto the cursor. Once settled it looks like Spotlight
final class ZoomRenderer: EffectRenderer {
    let isAnimated = true

    func draw(in ctx: CGContext, bounds: CGRect, spot: CGPoint?, elapsed: TimeInterval) {
        guard let center = spot else {
            drawDimWithHole(in: ctx, bounds: bounds, center: nil, radius: 0)
            return
        }
        // Start at the farthest screen corner, plus the line width so the ring starts off-screen too
        let start = FocusLines.outerRadius(center: center, bounds: bounds) + Config.ringWidth
        let radius = Zoom.radius(
            elapsed: elapsed,
            start: start,
            end: Config.spotRadius,
            duration: Config.zoomDuration,
            overshoot: Config.zoomOvershoot
        )
        drawDimWithHole(in: ctx, bounds: bounds, center: center, radius: radius)
    }
}

// MARK: - Focus Lines

/// Manga-style focus lines: radial wedges around the cursor, cycling through three patterns so they jitter
final class FocusLinesRenderer: EffectRenderer {
    let isAnimated = true
    private let frames: [[FocusLineWedge]]

    init() {
        frames = (0..<Config.focusLinesFrameCount).map { index in
            FocusLines.makeWedges(
                seed: UInt64(index + 1),
                count: Config.focusLinesCount,
                innerRadius: Config.focusLinesInnerRadius,
                innerJitter: Config.focusLinesInnerJitter,
                widthRange: Config.focusLinesWidthRange
            )
        }
    }

    func draw(in ctx: CGContext, bounds: CGRect, spot: CGPoint?, elapsed: TimeInterval) {
        ctx.setFillColor(NSColor.black.withAlphaComponent(Config.dimOpacity).cgColor)

        // Screens without the cursor dim fully
        guard let center = spot else {
            ctx.fill(bounds)
            return
        }

        let frameIndex = Int(elapsed / Config.focusLinesFrameInterval) % frames.count
        let outer = FocusLines.outerRadius(center: center, bounds: bounds)
        let path = CGMutablePath()
        for wedge in frames[frameIndex] {
            let points = FocusLines.trianglePoints(for: wedge, center: center, outerRadius: outer)
            path.move(to: points.apex)
            path.addLine(to: points.base1)
            path.addLine(to: points.base2)
            path.closeSubpath()
        }
        ctx.addPath(path)
        ctx.fillPath()
    }
}
