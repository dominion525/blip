import XCTest
@testable import BlipCore

final class ZoomTests: XCTestCase {
    private func radius(at elapsed: TimeInterval) -> CGFloat {
        Zoom.radius(elapsed: elapsed, start: 2000, end: 110, duration: 0.35, overshoot: 0.15)
    }

    func testStartsAtStartRadius() {
        XCTAssertEqual(radius(at: 0), 2000)
        XCTAssertEqual(radius(at: -1), 2000)
    }

    func testEndsAtEndRadius() {
        XCTAssertEqual(radius(at: 0.35), 110)
        XCTAssertEqual(radius(at: 10), 110)
    }

    func testReachesOvershootMinimumAtSplit() {
        XCTAssertEqual(radius(at: 0.35 * Zoom.overshootPoint), 110 * 0.85, accuracy: 0.001)
    }

    func testShrinksMonotonicallyUntilSplit() {
        let split = 0.35 * Zoom.overshootPoint
        var previous = radius(at: 0)
        for step in 1...20 {
            let value = radius(at: split * Double(step) / 20)
            XCTAssertLessThan(value, previous)
            previous = value
        }
    }

    func testGrowsBackMonotonicallyAfterSplit() {
        let split = 0.35 * Zoom.overshootPoint
        var previous = radius(at: split)
        for step in 1...20 {
            let value = radius(at: split + (0.35 - split) * Double(step) / 20)
            XCTAssertGreaterThanOrEqual(value, previous)
            previous = value
        }
    }

    func testFirstHalfIsFasterThanSecondHalfOfShrink() {
        let split = 0.35 * Zoom.overshootPoint
        let dropFirst = radius(at: 0) - radius(at: split / 2)
        let dropSecond = radius(at: split / 2) - radius(at: split)
        XCTAssertGreaterThan(dropFirst, dropSecond)
    }

    func testZeroDurationJumpsToEnd() {
        XCTAssertEqual(Zoom.radius(elapsed: 0.01, start: 2000, end: 110, duration: 0, overshoot: 0.15), 110)
        XCTAssertEqual(Zoom.radius(elapsed: 0, start: 2000, end: 110, duration: 0, overshoot: 0.15), 2000)
    }
}
