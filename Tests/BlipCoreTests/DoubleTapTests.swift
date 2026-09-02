import XCTest
@testable import BlipCore

final class DoubleTapTests: XCTestCase {
    func testSecondPressWithinIntervalFires() {
        var tracker = DoubleTapTracker(interval: 0.3)
        XCTAssertFalse(tracker.update(isDown: true, at: 0.00), "the first press does not fire")
        XCTAssertFalse(tracker.update(isDown: false, at: 0.05), "releasing does not fire")
        XCTAssertTrue(tracker.update(isDown: true, at: 0.20), "a second press within the interval fires")
        XCTAssertFalse(tracker.update(isDown: false, at: 0.25), "releasing after firing does not fire")
    }

    func testSecondPressAfterIntervalRestartsCount() {
        var tracker = DoubleTapTracker(interval: 0.3)
        _ = tracker.update(isDown: true, at: 0.00)
        _ = tracker.update(isDown: false, at: 0.05)
        XCTAssertFalse(tracker.update(isDown: true, at: 0.50), "a second press after the interval does not fire")
        _ = tracker.update(isDown: false, at: 0.55)
        XCTAssertTrue(tracker.update(isDown: true, at: 0.70), "the late press counts as a first press and the next one fires")
    }

    func testHoldingIsASinglePress() {
        var tracker = DoubleTapTracker(interval: 0.3)
        _ = tracker.update(isDown: true, at: 0.00)
        XCTAssertFalse(tracker.update(isDown: true, at: 0.10), "polling while held does not count as a press")
        XCTAssertFalse(tracker.update(isDown: true, at: 0.20), "holding the key never fires")
    }

    func testThirdPressStartsANewSequence() {
        var tracker = DoubleTapTracker(interval: 0.3)
        _ = tracker.update(isDown: true, at: 0.00)
        _ = tracker.update(isDown: false, at: 0.05)
        _ = tracker.update(isDown: true, at: 0.10)
        _ = tracker.update(isDown: false, at: 0.15)
        XCTAssertFalse(tracker.update(isDown: true, at: 0.20), "a third press right after firing does not fire")
        _ = tracker.update(isDown: false, at: 0.25)
        XCTAssertTrue(tracker.update(isDown: true, at: 0.30), "the third and fourth presses fire again")
    }

    /// Uses 0.25, which is exact in binary, to check the boundary itself
    func testExactlyIntervalFires() {
        var tracker = DoubleTapTracker(interval: 0.25)
        _ = tracker.update(isDown: true, at: 1.0)
        _ = tracker.update(isDown: false, at: 1.125)
        XCTAssertTrue(tracker.update(isDown: true, at: 1.25))
    }
}
