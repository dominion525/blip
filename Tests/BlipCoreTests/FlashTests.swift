import XCTest
@testable import BlipCore

final class FlashTests: XCTestCase {
    // MARK: Blink

    func testRingStartsVisible() {
        XCTAssertTrue(Flash.isRingVisible(elapsed: 0, period: 0.2))
    }

    func testRingAlternatesEveryHalfPeriod() {
        XCTAssertTrue(Flash.isRingVisible(elapsed: 0.05, period: 0.2))
        XCTAssertFalse(Flash.isRingVisible(elapsed: 0.15, period: 0.2))
        XCTAssertTrue(Flash.isRingVisible(elapsed: 0.25, period: 0.2))
        XCTAssertFalse(Flash.isRingVisible(elapsed: 0.35, period: 0.2))
    }

    func testZeroPeriodKeepsRingVisible() {
        XCTAssertTrue(Flash.isRingVisible(elapsed: 1, period: 0))
    }

    // MARK: Ripples

    func testFirstRippleAppearsAtStart() {
        let progresses = Flash.rippleProgresses(elapsed: 0, interval: 0.3, lifetime: 0.6)
        XCTAssertEqual(progresses, [0])
    }

    func testRipplesOverlapAccordingToIntervalAndLifetime() {
        // At 0.45 s: the ripple from 0 s (progress 0.75) and the one from 0.3 s (progress 0.25)
        let progresses = Flash.rippleProgresses(elapsed: 0.45, interval: 0.3, lifetime: 0.6)
        XCTAssertEqual(progresses.count, 2)
        XCTAssertEqual(progresses[0], 0.75, accuracy: 0.001)
        XCTAssertEqual(progresses[1], 0.25, accuracy: 0.001)
    }

    func testExpiredRipplesAreDropped() {
        // At 0.9 s: the 0 s ripple has expired, the 0.3 s one reaches 1.0 and expires, 0.6 s is at 0.5, 0.9 s at 0
        let progresses = Flash.rippleProgresses(elapsed: 0.9, interval: 0.3, lifetime: 0.6)
        XCTAssertEqual(progresses.count, 2)
        XCTAssertEqual(progresses[0], 0.5, accuracy: 0.001)
        XCTAssertEqual(progresses[1], 0, accuracy: 0.001)
    }

    func testProgressesStayWithinZeroAndOne() {
        for step in 0...100 {
            let progresses = Flash.rippleProgresses(elapsed: Double(step) * 0.037, interval: 0.3, lifetime: 0.6)
            XCTAssertTrue(progresses.allSatisfy { $0 >= 0 && $0 < 1 })
        }
    }

    func testInvalidParametersGiveNoRipples() {
        XCTAssertEqual(Flash.rippleProgresses(elapsed: 1, interval: 0, lifetime: 0.6), [])
        XCTAssertEqual(Flash.rippleProgresses(elapsed: 1, interval: 0.3, lifetime: 0), [])
        XCTAssertEqual(Flash.rippleProgresses(elapsed: -1, interval: 0.3, lifetime: 0.6), [])
    }
}
