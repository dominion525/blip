// Coordinate math and display-configuration matching. Pure functions only, no AppKit.
// Tests: Tests/BlipCoreTests/GeometryTests.swift (run with swift test).

import CoreGraphics

public enum Geometry {
    /// Returns the window-local point for the global `mouse` location if it lies inside the window `frame`,
    /// or nil when it does not (that window then dims fully without a hole).
    /// NSEvent.mouseLocation and NSWindow.frame share the same global space (origin at the bottom-left of the primary display, y up), so subtracting the frame origin is the whole conversion.
    /// Edge rules follow CGRect.contains: minX / minY are inside, maxX / maxY outside.
    /// A cursor on the shared edge of two adjacent displays belongs to exactly one of them.
    public static func spotCenter(mouse: CGPoint, in frame: CGRect) -> CGPoint? {
        guard frame.contains(mouse) else { return nil }
        return CGPoint(x: mouse.x - frame.minX, y: mouse.y - frame.minY)
    }

    /// Whether the frames of the overlay windows still match the current screen frames, in order.
    /// The caller rebuilds the windows when they do not.
    public static func framesMatch(windows: [CGRect], screens: [CGRect]) -> Bool {
        windows.count == screens.count && zip(windows, screens).allSatisfy { $0 == $1 }
    }

    /// The bounding rect of the circle of `radius` around `center`. Used to draw the hole and the ring.
    public static func holeRect(center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}
