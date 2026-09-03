// Timing of the Flash effect. No drawing here.
// Derives the ring blink state and the progress of ripples expanding from the hole from the elapsed time.

import Foundation

public enum Flash {
    /// Blink: on for the first half of every `period`, off for the second half. On at 0
    public static func isRingVisible(elapsed: TimeInterval, period: TimeInterval) -> Bool {
        guard period > 0 else { return true }
        let phase = elapsed.truncatingRemainder(dividingBy: period)
        return phase < period / 2
    }

    /// Progress of every visible ripple (0 just emitted, 1 gone), oldest first.
    /// Ripples are emitted at 0 and every `interval` after that, and live for `lifetime` seconds
    public static func rippleProgresses(elapsed: TimeInterval, interval: TimeInterval, lifetime: TimeInterval) -> [Double] {
        guard interval > 0, lifetime > 0, elapsed >= 0 else { return [] }
        var progresses: [Double] = []
        var emittedAt: TimeInterval = 0
        while emittedAt <= elapsed {
            let age = elapsed - emittedAt
            if age < lifetime {
                progresses.append(age / lifetime)
            }
            emittedAt += interval
        }
        return progresses
    }
}
