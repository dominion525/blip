import XCTest
@testable import BlipCore

final class GeometryTests: XCTestCase {
    let primary = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let rightOfPrimary = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
    let leftOfPrimary = CGRect(x: -1440, y: 200, width: 1440, height: 900)

    // MARK: spotCenter

    func testSpotCenterInsidePrimaryKeepsCoordinates() {
        XCTAssertEqual(Geometry.spotCenter(mouse: CGPoint(x: 100, y: 200), in: primary), CGPoint(x: 100, y: 200))
    }

    func testSpotCenterOnRightScreenSubtractsOrigin() {
        XCTAssertEqual(Geometry.spotCenter(mouse: CGPoint(x: 2000, y: 300), in: rightOfPrimary), CGPoint(x: 80, y: 300))
    }

    func testSpotCenterOnLeftScreenWithNegativeOrigin() {
        XCTAssertEqual(Geometry.spotCenter(mouse: CGPoint(x: -1000, y: 500), in: leftOfPrimary), CGPoint(x: 440, y: 300))
    }

    func testSpotCenterOutsideScreenIsNil() {
        XCTAssertNil(Geometry.spotCenter(mouse: CGPoint(x: 2000, y: 300), in: primary))
        XCTAssertNil(Geometry.spotCenter(mouse: CGPoint(x: 100, y: 200), in: rightOfPrimary))
    }

    /// A shared edge is outside for the screen whose maxX it is and inside for the one whose minX it is; never both
    func testSpotCenterOnSharedEdgeBelongsToOneScreen() {
        XCTAssertNil(Geometry.spotCenter(mouse: CGPoint(x: 1920, y: 100), in: primary))
        XCTAssertEqual(Geometry.spotCenter(mouse: CGPoint(x: 1920, y: 100), in: rightOfPrimary), CGPoint(x: 0, y: 100))
    }

    /// The top row (y == maxY) is inside: the coordinate of a cursor parked against the menu bar
    func testSpotCenterAtTopEdgeIsInside() {
        XCTAssertEqual(Geometry.spotCenter(mouse: CGPoint(x: 500, y: 1080), in: primary), CGPoint(x: 500, y: 1080))
    }

    /// The bottom edge (y == minY) is outside, so a vertically shared edge belongs to the upper screen only
    func testSpotCenterOnVerticalSharedEdgeBelongsToTheUpperScreen() {
        let above = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
        XCTAssertNil(Geometry.spotCenter(mouse: CGPoint(x: 500, y: 1080), in: above))
        XCTAssertEqual(Geometry.spotCenter(mouse: CGPoint(x: 500, y: 1080), in: primary), CGPoint(x: 500, y: 1080))
        XCTAssertEqual(Geometry.spotCenter(mouse: CGPoint(x: 500, y: 2160), in: above), CGPoint(x: 500, y: 1080))
    }

    func testSpotCenterAtLeftEdgeIsInside() {
        XCTAssertEqual(Geometry.spotCenter(mouse: CGPoint(x: 0, y: 500), in: primary), CGPoint(x: 0, y: 500))
    }

    func testSpotCenterAtBottomEdgeIsOutside() {
        XCTAssertNil(Geometry.spotCenter(mouse: CGPoint(x: 500, y: 0), in: primary))
    }

    // MARK: framesMatch

    func testFramesMatchSameConfiguration() {
        XCTAssertTrue(Geometry.framesMatch(windows: [primary, rightOfPrimary], screens: [primary, rightOfPrimary]))
    }

    func testFramesMatchDetectsAddedScreen() {
        XCTAssertFalse(Geometry.framesMatch(windows: [primary], screens: [primary, rightOfPrimary]))
    }

    func testFramesMatchDetectsRemovedScreen() {
        XCTAssertFalse(Geometry.framesMatch(windows: [primary, rightOfPrimary], screens: [primary]))
    }

    func testFramesMatchDetectsDifferentFrameWithSameCount() {
        XCTAssertFalse(Geometry.framesMatch(windows: [primary, rightOfPrimary], screens: [primary, leftOfPrimary]))
    }

    func testFramesMatchDetectsResolutionChange() {
        XCTAssertFalse(Geometry.framesMatch(windows: [primary], screens: [CGRect(x: 0, y: 0, width: 2560, height: 1440)]))
    }

    func testFramesMatchBothEmpty() {
        XCTAssertTrue(Geometry.framesMatch(windows: [], screens: []))
    }

    /// False before any window exists, so the caller creates them on first show
    func testFramesMatchNoWindowsYet() {
        XCTAssertFalse(Geometry.framesMatch(windows: [], screens: [primary]))
    }

    // MARK: holeRect

    func testHoleRectIsCenteredWithDiameterSize() {
        XCTAssertEqual(Geometry.holeRect(center: CGPoint(x: 500, y: 400), radius: 110),
                       CGRect(x: 390, y: 290, width: 220, height: 220))
    }

    func testHoleRectNearEdgeIsNotClamped() {
        XCTAssertEqual(Geometry.holeRect(center: CGPoint(x: 50, y: 50), radius: 110),
                       CGRect(x: -60, y: -60, width: 220, height: 220))
    }
}
