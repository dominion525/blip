// Detects a double-tap of a modifier key. A pure state machine fed with timestamps and key state, no AppKit.
// Tests: Tests/DoubleTapTests.swift (run with test.sh).

import Foundation

struct DoubleTapTracker {
    /// Maximum time between the first and second press, in seconds
    let interval: TimeInterval

    private var wasDown = false
    private var lastPressTime: TimeInterval?

    init(interval: TimeInterval) {
        self.interval = interval
    }

    /// Feed one observation. `isDown` is the current key state, `time` a monotonically increasing clock.
    /// Returns true only when two press edges occur within `interval`.
    /// A third press starts a new sequence, so holding down or hammering the key does not fire repeatedly.
    mutating func update(isDown: Bool, at time: TimeInterval) -> Bool {
        defer { wasDown = isDown }
        guard isDown && !wasDown else { return false }
        if let last = lastPressTime, time - last <= interval {
            lastPressTime = nil
            return true
        }
        lastPressTime = time
        return false
    }
}
