import CoreGraphics
import Foundation

/// Decides when a cursor that was moved has come to rest.
///
/// The effect is meant to end once its user has found the cursor, and moving it is the evidence of
/// that. Ending on the movement itself would take the effect away mid-sweep, when it is still doing
/// its job; ending once the movement stops leaves it up until the cursor has arrived somewhere.
///
/// A pure state machine so the decision can be tested without a cursor: feed it positions and a
/// clock, and it says whether to dismiss.
public struct DismissOnRest: Sendable {
    /// How far the cursor has to travel before it counts as moved, in points. Cursors jitter by a
    /// point or so while a hand rests on the trackpad, which is not someone looking for it
    public let movementThreshold: CGFloat
    /// How long the cursor has to hold still after moving before the effect ends, in seconds
    public let restDuration: TimeInterval

    private var origin: CGPoint?
    private var hasMoved = false
    private var stillSince: TimeInterval?

    public init(movementThreshold: CGFloat, restDuration: TimeInterval) {
        self.movementThreshold = movementThreshold
        self.restDuration = restDuration
    }

    /// Call when the effect appears, with where the cursor is. Any movement is measured from here
    public mutating func begin(at position: CGPoint, now: TimeInterval) {
        origin = position
        hasMoved = false
        stillSince = nil
        _ = now
    }

    /// Call on every tracking tick. Returns true once the cursor has moved and then held still
    public mutating func shouldDismiss(at position: CGPoint, now: TimeInterval) -> Bool {
        guard let origin else { return false }

        if !hasMoved {
            guard Self.distance(from: origin, to: position) >= movementThreshold else { return false }
            hasMoved = true
            stillSince = now
            self.origin = position
            return false
        }

        // Moving again restarts the wait, so a pause partway through a sweep does not end the effect
        if Self.distance(from: origin, to: position) >= movementThreshold {
            self.origin = position
            stillSince = now
            return false
        }

        guard let stillSince else { return false }
        return now - stillSince >= restDuration
    }

    private static func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
