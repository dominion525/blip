import XCTest
@testable import BlipCore

final class FocusLinesTests: XCTestCase {
    private func wedges(seed: UInt64 = 1, count: Int = 150) -> [FocusLineWedge] {
        FocusLines.makeWedges(seed: seed, count: count, innerRadius: 80, innerJitter: 30, widthRange: 6...22)
    }

    func testMakesRequestedCount() {
        XCTAssertEqual(wedges(count: 150).count, 150)
        XCTAssertEqual(wedges(count: 0).count, 0)
    }

    func testSameSeedGivesSamePattern() {
        XCTAssertEqual(wedges(seed: 7), wedges(seed: 7))
    }

    func testDifferentSeedsGiveDifferentPatterns() {
        XCTAssertNotEqual(wedges(seed: 1), wedges(seed: 2))
    }

    func testValuesStayWithinRanges() {
        for wedge in wedges() {
            XCTAssertGreaterThanOrEqual(wedge.angle, 0)
            XCTAssertLessThan(wedge.angle, 2 * .pi)
            XCTAssertGreaterThanOrEqual(wedge.innerRadius, 50)
            XCTAssertLessThanOrEqual(wedge.innerRadius, 110)
            XCTAssertGreaterThanOrEqual(wedge.outerWidth, 6)
            XCTAssertLessThanOrEqual(wedge.outerWidth, 22)
        }
    }

    func testInnerRadiusNeverNegative() {
        let result = FocusLines.makeWedges(seed: 3, count: 200, innerRadius: 10, innerJitter: 50, widthRange: 1...2)
        XCTAssertTrue(result.allSatisfy { $0.innerRadius >= 0 })
    }

    func testOuterRadiusReachesFarthestCorner() {
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        // From a center near the lower left, the upper right corner is farthest
        let radius = FocusLines.outerRadius(center: CGPoint(x: 100, y: 100), bounds: bounds)
        XCTAssertEqual(radius, hypot(1820, 980), accuracy: 0.001)
        // From the center all four corners are equidistant
        let fromCenter = FocusLines.outerRadius(center: CGPoint(x: 960, y: 540), bounds: bounds)
        XCTAssertEqual(fromCenter, hypot(960, 540), accuracy: 0.001)
    }

    func testTriangleApexIsAtInnerRadiusAlongAngle() {
        let wedge = FocusLineWedge(angle: 0, innerRadius: 80, outerWidth: 20)
        let points = FocusLines.trianglePoints(for: wedge, center: CGPoint(x: 500, y: 400), outerRadius: 1000)
        XCTAssertEqual(points.apex.x, 580, accuracy: 0.001)
        XCTAssertEqual(points.apex.y, 400, accuracy: 0.001)
        // At angle 0 the outer points sit at x = 1500 with y offset by ±10
        XCTAssertEqual(points.base1.x, 1500, accuracy: 0.001)
        XCTAssertEqual(points.base2.x, 1500, accuracy: 0.001)
        XCTAssertEqual(abs(points.base1.y - points.base2.y), 20, accuracy: 0.001)
        XCTAssertEqual((points.base1.y + points.base2.y) / 2, 400, accuracy: 0.001)
    }

    func testTriangleFollowsAngle() {
        let wedge = FocusLineWedge(angle: .pi / 2, innerRadius: 100, outerWidth: 10)
        let points = FocusLines.trianglePoints(for: wedge, center: .zero, outerRadius: 500)
        XCTAssertEqual(points.apex.x, 0, accuracy: 0.001)
        XCTAssertEqual(points.apex.y, 100, accuracy: 0.001)
        XCTAssertEqual(points.base1.y, 500, accuracy: 0.001)
        XCTAssertEqual(points.base2.y, 500, accuracy: 0.001)
    }
}
