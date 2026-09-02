// Behavior of Geometry

import Foundation
enum GeometryTests {
    static func run() {
        let primary = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let rightOfPrimary = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
        let leftOfPrimary = CGRect(x: -1440, y: 200, width: 1440, height: 900)

        // spotCenter: inside, the frame origin is subtracted
        check(Geometry.spotCenter(mouse: CGPoint(x: 100, y: 200), in: primary) == CGPoint(x: 100, y: 200),
              "spotCenter: inside the primary screen the point is unchanged")
        check(Geometry.spotCenter(mouse: CGPoint(x: 2000, y: 300), in: rightOfPrimary) == CGPoint(x: 80, y: 300),
              "spotCenter: on the screen to the right frame.minX is subtracted")
        check(Geometry.spotCenter(mouse: CGPoint(x: -1000, y: 500), in: leftOfPrimary) == CGPoint(x: 440, y: 300),
              "spotCenter: minX / minY are subtracted on a screen to the left with negative coordinates too")

        // spotCenter: nil when outside
        check(Geometry.spotCenter(mouse: CGPoint(x: 2000, y: 300), in: primary) == nil,
              "spotCenter: outside the screen is nil")
        check(Geometry.spotCenter(mouse: CGPoint(x: 100, y: 200), in: rightOfPrimary) == nil,
              "spotCenter: a point on another screen is nil")

        // spotCenter: edges. minX is inside and maxX outside, so a shared edge belongs to the right screen only
        check(Geometry.spotCenter(mouse: CGPoint(x: 1920, y: 100), in: primary) == nil,
              "spotCenter: on maxX is outside the primary screen")
        check(Geometry.spotCenter(mouse: CGPoint(x: 1920, y: 100), in: rightOfPrimary) == CGPoint(x: 0, y: 100),
              "spotCenter: on maxX is inside the screen to the right (x = 0)")
        check(Geometry.spotCenter(mouse: CGPoint(x: 0, y: 0), in: primary) == CGPoint(x: 0, y: 0),
              "spotCenter: the origin is inside")

        // framesMatch
        check(Geometry.framesMatch(windows: [primary, rightOfPrimary], screens: [primary, rightOfPrimary]),
              "framesMatch: the same configuration is true")
        check(!Geometry.framesMatch(windows: [primary], screens: [primary, rightOfPrimary]),
              "framesMatch: more screens is false")
        check(!Geometry.framesMatch(windows: [primary, rightOfPrimary], screens: [primary]),
              "framesMatch: fewer screens is false")
        check(!Geometry.framesMatch(windows: [primary, rightOfPrimary], screens: [primary, leftOfPrimary]),
              "framesMatch: same count but different frames is false")
        check(!Geometry.framesMatch(windows: [primary], screens: [CGRect(x: 0, y: 0, width: 2560, height: 1440)]),
              "framesMatch: a resolution change (different size) is false")
        check(Geometry.framesMatch(windows: [], screens: []),
              "framesMatch: both empty is true")
        check(!Geometry.framesMatch(windows: [], screens: [primary]),
              "framesMatch: no windows yet but screens present is false (created on first show)")

        // holeRect
        check(Geometry.holeRect(center: CGPoint(x: 500, y: 400), radius: 110) == CGRect(x: 390, y: 290, width: 220, height: 220),
              "holeRect: origin is center minus radius, size is the diameter")
        check(Geometry.holeRect(center: CGPoint(x: 50, y: 50), radius: 110) == CGRect(x: -60, y: -60, width: 220, height: 220),
              "holeRect: a negative origin near the screen edge is not clamped")
    }
}
