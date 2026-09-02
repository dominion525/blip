// Radius curve of the Zoom effect's hole over time. No drawing here.
// The hole shrinks quickly from a large radius, overshoots slightly below the end radius, then settles back.

import Foundation

public enum Zoom {
    /// Fraction of the duration at which the overshoot (minimum radius) is reached
    public static let overshootPoint: Double = 0.75

    /// The radius at `elapsed` seconds.
    /// `start` at 0, `end` from `duration` on. At duration × overshootPoint it reaches end × (1 − overshoot), then returns to `end`.
    /// The shrink eases out (fast first, slowing down); the return eases in and out.
    public static func radius(
        elapsed: TimeInterval,
        start: CGFloat,
        end: CGFloat,
        duration: TimeInterval,
        overshoot: CGFloat
    ) -> CGFloat {
        guard duration > 0, elapsed > 0 else { return elapsed > 0 ? end : start }
        guard elapsed < duration else { return end }

        let minimum = end * (1 - overshoot)
        let split = duration * overshootPoint
        if elapsed < split {
            let t = CGFloat(elapsed / split)
            return start + (minimum - start) * easeOutCubic(t)
        }
        let t = CGFloat((elapsed - split) / (duration - split))
        return minimum + (end - minimum) * easeInOutQuad(t)
    }

    static func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let inverse = 1 - t
        return 1 - inverse * inverse * inverse
    }

    static func easeInOutQuad(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) / 2
    }
}
