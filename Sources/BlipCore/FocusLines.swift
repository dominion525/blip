// Shapes for the Focus Lines effect (manga-style speed lines). No drawing here.
// Each wedge is a thin triangle pointing at the cursor; base distance, angle, and outer width are randomized.

import CoreGraphics

/// One wedge: its direction, the distance to its tip, and its width at the outer end
public struct FocusLineWedge: Equatable {
    /// Direction from the center, in radians, in [0, 2π)
    public let angle: CGFloat
    /// Distance from the center to the tip (the pointed end)
    public let innerRadius: CGFloat
    /// Width at the outer end (at outerRadius)
    public let outerWidth: CGFloat

    public init(angle: CGFloat, innerRadius: CGFloat, outerWidth: CGFloat) {
        self.angle = angle
        self.innerRadius = innerRadius
        self.outerWidth = outerWidth
    }
}

public enum FocusLines {
    /// Generates `count` wedges. The same seed gives the same pattern.
    /// Tips are scattered around `innerRadius` by ±innerJitter (never below 0); outer widths fall within `widthRange`
    public static func makeWedges(
        seed: UInt64,
        count: Int,
        innerRadius: CGFloat,
        innerJitter: CGFloat,
        widthRange: ClosedRange<CGFloat>
    ) -> [FocusLineWedge] {
        var random = SeededRandom(seed: seed)
        return (0..<count).map { _ in
            let angle = CGFloat.random(in: 0..<(2 * .pi), using: &random)
            let jitter = CGFloat.random(in: -innerJitter...innerJitter, using: &random)
            let width = CGFloat.random(in: widthRange, using: &random)
            return FocusLineWedge(angle: angle, innerRadius: max(0, innerRadius + jitter), outerWidth: width)
        }
    }

    /// Distance from the center to the farthest corner of `bounds`. Wedges extended this far always leave the screen
    public static func outerRadius(center: CGPoint, bounds: CGRect) -> CGFloat {
        let corners = [
            CGPoint(x: bounds.minX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.minY),
            CGPoint(x: bounds.minX, y: bounds.maxY),
            CGPoint(x: bounds.maxX, y: bounds.maxY),
        ]
        return corners.map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? 0
    }

    /// The three vertices of a wedge: `apex` is the tip near the center, `base1` and `base2` the outer end
    public static func trianglePoints(
        for wedge: FocusLineWedge,
        center: CGPoint,
        outerRadius: CGFloat
    ) -> (apex: CGPoint, base1: CGPoint, base2: CGPoint) {
        let direction = CGPoint(x: cos(wedge.angle), y: sin(wedge.angle))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let apex = CGPoint(
            x: center.x + direction.x * wedge.innerRadius,
            y: center.y + direction.y * wedge.innerRadius
        )
        let outer = CGPoint(
            x: center.x + direction.x * outerRadius,
            y: center.y + direction.y * outerRadius
        )
        let half = wedge.outerWidth / 2
        let base1 = CGPoint(x: outer.x + normal.x * half, y: outer.y + normal.y * half)
        let base2 = CGPoint(x: outer.x - normal.x * half, y: outer.y - normal.y * half)
        return (apex, base1, base2)
    }
}
