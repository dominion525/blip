import CoreGraphics
import XCTest
@testable import BlipCore

final class DismissOnRestTests: XCTestCase {
    private func makeDecider() -> DismissOnRest {
        DismissOnRest(movementThreshold: 10, restDuration: 0.3)
    }

    func testHoldingStillFromTheStartNeverDismisses() {
        var decider = makeDecider()
        decider.begin(at: .zero, now: 0)
        for tick in 1...100 {
            XCTAssertFalse(decider.shouldDismiss(at: .zero, now: Double(tick) / 60))
        }
    }

    /// Cursors drift a point or two while a hand rests on the trackpad. That is not someone
    /// looking for it, so it must not start the countdown
    func testDriftBelowTheThresholdIsNotMovement() {
        var decider = makeDecider()
        decider.begin(at: .zero, now: 0)
        XCTAssertFalse(decider.shouldDismiss(at: CGPoint(x: 3, y: 3), now: 1))
        XCTAssertFalse(decider.shouldDismiss(at: CGPoint(x: 3, y: 3), now: 5), "still no movement to rest from")
    }

    func testDismissesAfterMovingThenHoldingStill() {
        var decider = makeDecider()
        decider.begin(at: .zero, now: 0)
        XCTAssertFalse(decider.shouldDismiss(at: CGPoint(x: 50, y: 0), now: 1), "moving is not enough on its own")
        XCTAssertFalse(decider.shouldDismiss(at: CGPoint(x: 50, y: 0), now: 1.2), "still inside the rest window")
        XCTAssertTrue(decider.shouldDismiss(at: CGPoint(x: 50, y: 0), now: 1.3))
    }

    /// The point of resting rather than moving: a sweep that pauses partway is still a sweep
    func testPausingPartwayThroughRestartsTheWait() {
        var decider = makeDecider()
        decider.begin(at: .zero, now: 0)
        XCTAssertFalse(decider.shouldDismiss(at: CGPoint(x: 50, y: 0), now: 1))
        XCTAssertFalse(decider.shouldDismiss(at: CGPoint(x: 50, y: 0), now: 1.2))
        XCTAssertFalse(decider.shouldDismiss(at: CGPoint(x: 200, y: 0), now: 1.25), "moved again")
        XCTAssertFalse(decider.shouldDismiss(at: CGPoint(x: 200, y: 0), now: 1.5), "the wait started over")
        XCTAssertTrue(decider.shouldDismiss(at: CGPoint(x: 200, y: 0), now: 1.56))
    }

    func testMeasuresDistanceInBothAxes() {
        var decider = makeDecider()
        decider.begin(at: .zero, now: 0)
        // 6-8-10 triangle: each axis is under the threshold, the distance is exactly on it
        XCTAssertFalse(decider.shouldDismiss(at: CGPoint(x: 6, y: 8), now: 1))
        XCTAssertTrue(decider.shouldDismiss(at: CGPoint(x: 6, y: 8), now: 1.3), "the move counted, so the rest counts")
    }

    func testAskingBeforeBeginningDismissesNothing() {
        var decider = makeDecider()
        XCTAssertFalse(decider.shouldDismiss(at: CGPoint(x: 500, y: 500), now: 10))
    }

    /// Showing the effect again while it is up restarts the decision from wherever the cursor is
    func testBeginningAgainForgetsTheEarlierMovement() {
        var decider = makeDecider()
        decider.begin(at: .zero, now: 0)
        XCTAssertFalse(decider.shouldDismiss(at: CGPoint(x: 50, y: 0), now: 1))
        decider.begin(at: CGPoint(x: 50, y: 0), now: 1.1)
        XCTAssertFalse(decider.shouldDismiss(at: CGPoint(x: 50, y: 0), now: 2), "no movement since starting over")
    }
}
