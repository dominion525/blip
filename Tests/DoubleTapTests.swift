// Behavior of DoubleTapTracker

import Foundation

enum DoubleTapTests {
    static func run() {
        // Press, release, press within 0.3 s
        var tracker = DoubleTapTracker(interval: 0.3)
        check(!tracker.update(isDown: true, at: 0.00), "doubleTap: the first press does not fire")
        check(!tracker.update(isDown: false, at: 0.05), "doubleTap: releasing does not fire")
        check(tracker.update(isDown: true, at: 0.20), "doubleTap: a second press within the interval fires")
        check(!tracker.update(isDown: false, at: 0.25), "doubleTap: releasing after firing does not fire")

        // Past the interval the count restarts
        tracker = DoubleTapTracker(interval: 0.3)
        _ = tracker.update(isDown: true, at: 0.00)
        _ = tracker.update(isDown: false, at: 0.05)
        check(!tracker.update(isDown: true, at: 0.50), "doubleTap: a second press after the interval does not fire")
        _ = tracker.update(isDown: false, at: 0.55)
        check(tracker.update(isDown: true, at: 0.70), "doubleTap: the late press counts as a first press and the next one fires")

        // Holding the key is a single press
        tracker = DoubleTapTracker(interval: 0.3)
        _ = tracker.update(isDown: true, at: 0.00)
        check(!tracker.update(isDown: true, at: 0.10), "doubleTap: polling while held does not count as a press")
        check(!tracker.update(isDown: true, at: 0.20), "doubleTap: holding the key never fires")

        // A third press starts a new sequence
        tracker = DoubleTapTracker(interval: 0.3)
        _ = tracker.update(isDown: true, at: 0.00)
        _ = tracker.update(isDown: false, at: 0.05)
        _ = tracker.update(isDown: true, at: 0.10)
        _ = tracker.update(isDown: false, at: 0.15)
        check(!tracker.update(isDown: true, at: 0.20), "doubleTap: a third press right after firing does not fire")
        _ = tracker.update(isDown: false, at: 0.25)
        check(tracker.update(isDown: true, at: 0.30), "doubleTap: the third and fourth presses fire again")

        // Boundary: exactly interval fires (uses 0.25, which is exact in binary)
        tracker = DoubleTapTracker(interval: 0.25)
        _ = tracker.update(isDown: true, at: 1.0)
        _ = tracker.update(isDown: false, at: 1.125)
        check(tracker.update(isDown: true, at: 1.25), "doubleTap: exactly the interval fires")
    }
}
