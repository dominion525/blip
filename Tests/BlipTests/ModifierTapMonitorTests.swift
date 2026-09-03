import XCTest
import BlipCore
@testable import Blip

final class ModifierTapMonitorTests: XCTestCase {
    // MARK: Permission and tap lifecycle (OS touch points replaced with fakes)

    private final class FakeTap: EventTap {
        var isEnabled = true
        var invalidated = false
        let handler: (CGEventType, CGEvent) -> Void
        init(handler: @escaping (CGEventType, CGEvent) -> Void) { self.handler = handler }
        func enable() { isEnabled = true }
        func invalidate() { invalidated = true; isEnabled = false }
    }

    private final class Harness {
        var permission = false
        var requests = 0
        var factoryCalls = 0
        var factoryFails = false
        var taps: [FakeTap] = []
        var doubleTaps = 0
        var clock: TimeInterval = 1000
        var statusChanges: [ModifierTapMonitor.Status] = []
        lazy var monitor: ModifierTapMonitor = {
            let monitor = ModifierTapMonitor(
                interval: 0.3,
                permissionCheck: { [unowned self] in self.permission },
                requestPermission: { [unowned self] in self.requests += 1 },
                makeTap: { [unowned self] handler in
                    self.factoryCalls += 1
                    if self.factoryFails { return nil }
                    let tap = FakeTap(handler: handler)
                    self.taps.append(tap)
                    return tap
                },
                now: { [unowned self] in self.clock },
                onDoubleTap: { [unowned self] in self.doubleTaps += 1 }
            )
            monitor.onStatusChange = { [unowned self] in self.statusChanges.append($0) }
            return monitor
        }()
    }

    func testCheckIntervalBacksOffWhileWaiting() {
        let h = Harness()
        h.monitor.setModifier(.leftControl)
        XCTAssertEqual(h.monitor.nextCheckInterval, ModifierTapMonitor.waitingCheckInterval, "every second right after entering the waiting state")
        h.clock += ModifierTapMonitor.attentiveDuration + 1
        XCTAssertEqual(h.monitor.nextCheckInterval, ModifierTapMonitor.idleWaitingCheckInterval, "every 10 seconds after a minute")
        h.permission = true
        h.monitor.reconcile()
        XCTAssertEqual(h.monitor.nextCheckInterval, ModifierTapMonitor.activeCheckInterval, "every 30 seconds while active")
        h.monitor.setModifier(.off)
        XCTAssertEqual(h.monitor.nextCheckInterval, 0)
    }

    /// Losing permission restarts the fast checks
    func testBackOffRestartsAfterPermissionLoss() {
        let h = Harness()
        h.permission = true
        h.monitor.setModifier(.leftControl)
        h.clock += 500
        h.permission = false
        h.monitor.reconcile()
        XCTAssertEqual(h.monitor.nextCheckInterval, ModifierTapMonitor.waitingCheckInterval)
    }

    func testStatusChangesAreReported() {
        let h = Harness()
        h.monitor.setModifier(.leftControl)
        h.permission = true
        h.monitor.reconcile()
        h.permission = false
        h.monitor.reconcile()
        h.monitor.setModifier(.off)
        XCTAssertEqual(h.statusChanges, [.waitingForPermission, .active, .waitingForPermission, .off])
    }

    func testCheckNowReconcilesImmediately() {
        let h = Harness()
        h.monitor.setModifier(.leftControl)
        h.permission = true
        h.monitor.checkNow()
        XCTAssertEqual(h.monitor.status, .active)
    }

    /// Synthesizes a flagsChanged event
    private func flagsEvent(keyCode: CGKeyCode, flags: UInt64) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
        event.type = .flagsChanged
        event.flags = CGEventFlags(rawValue: flags)
        return event
    }

    func testWithoutPermissionItWaitsAndRequestsOnce() {
        let h = Harness()
        h.monitor.setModifier(.leftControl)
        XCTAssertEqual(h.monitor.status, .waitingForPermission)
        XCTAssertEqual(h.requests, 1)
        XCTAssertEqual(h.factoryCalls, 0)
        h.monitor.reconcile()
        h.monitor.reconcile()
        XCTAssertEqual(h.requests, 1, "only one request while waiting")
        XCTAssertEqual(h.factoryCalls, 0)
    }

    func testTapIsCreatedOncePermissionArrives() {
        let h = Harness()
        h.monitor.setModifier(.leftControl)
        h.permission = true
        h.monitor.reconcile()
        XCTAssertEqual(h.monitor.status, .active)
        XCTAssertEqual(h.factoryCalls, 1)
        XCTAssertEqual(h.taps.count, 1)
    }

    func testFailedTapCreationIsRetried() {
        let h = Harness()
        h.permission = true
        h.factoryFails = true
        h.monitor.setModifier(.leftControl)
        XCTAssertEqual(h.monitor.status, .waitingForPermission)
        XCTAssertEqual(h.factoryCalls, 1)
        h.factoryFails = false
        h.monitor.reconcile()
        XCTAssertEqual(h.monitor.status, .active)
        XCTAssertEqual(h.factoryCalls, 2)
    }

    /// Revoking permission tears the tap down and returns to waiting; granting it again rebuilds the tap
    func testPermissionLossTearsDownAndRegrantRebuilds() {
        let h = Harness()
        h.permission = true
        h.monitor.setModifier(.leftControl)
        XCTAssertEqual(h.monitor.status, .active)

        h.permission = false
        h.monitor.reconcile()
        XCTAssertEqual(h.monitor.status, .waitingForPermission)
        XCTAssertTrue(h.taps[0].invalidated)
        XCTAssertEqual(h.requests, 1, "requests again after revocation")

        h.permission = true
        h.monitor.reconcile()
        XCTAssertEqual(h.monitor.status, .active)
        XCTAssertEqual(h.taps.count, 2, "creates a new tap")
        XCTAssertFalse(h.taps[1].invalidated)
    }

    func testDisabledTapIsReenabledOnCheck() {
        let h = Harness()
        h.permission = true
        h.monitor.setModifier(.leftControl)
        h.taps[0].isEnabled = false
        h.monitor.reconcile()
        XCTAssertTrue(h.taps[0].isEnabled)
        XCTAssertEqual(h.taps.count, 1, "does not rebuild")
    }

    func testOffStopsAndInvalidatesTap() {
        let h = Harness()
        h.permission = true
        h.monitor.setModifier(.leftControl)
        h.monitor.setModifier(.off)
        XCTAssertEqual(h.monitor.status, .off)
        XCTAssertTrue(h.taps[0].invalidated)
        h.monitor.reconcile()
        XCTAssertEqual(h.factoryCalls, 1, "nothing is created while off")
    }

    /// Two synthesized flagsChanged presses fire
    func testDoubleTapFiresThroughTheTap() {
        let h = Harness()
        h.permission = true
        h.monitor.setModifier(.leftControl)
        let handler = h.taps[0].handler
        let down: UInt64 = 0x40000 | 0x1
        handler(.flagsChanged, flagsEvent(keyCode: 59, flags: down))
        handler(.flagsChanged, flagsEvent(keyCode: 59, flags: 0))
        handler(.flagsChanged, flagsEvent(keyCode: 59, flags: down))
        XCTAssertEqual(h.doubleTaps, 1)
        handler(.flagsChanged, flagsEvent(keyCode: 62, flags: down))
        XCTAssertEqual(h.doubleTaps, 1, "right Control is ignored")
    }

    func testTapDisabledEventReenablesTheTap() {
        let h = Harness()
        h.permission = true
        h.monitor.setModifier(.leftControl)
        h.taps[0].isEnabled = false
        h.taps[0].handler(.tapDisabledByTimeout, flagsEvent(keyCode: 59, flags: 0))
        XCTAssertTrue(h.taps[0].isEnabled)
    }

    private let leftControl: Int64 = 59
    private let rightControl: Int64 = 62
    private let leftShift: Int64 = 56

    func testLeftControlPressedAloneIsDown() {
        XCTAssertEqual(
            ModifierTapMonitor.isPressedAlone(flags: [.maskControl], keyCode: leftControl, modifier: .leftControl),
            true
        )
    }

    func testLeftControlReleasedIsUp() {
        XCTAssertEqual(
            ModifierTapMonitor.isPressedAlone(flags: [], keyCode: leftControl, modifier: .leftControl),
            false
        )
    }

    /// Right Control events are ignored while watching left Control
    func testOtherSideIsIgnored() {
        XCTAssertNil(ModifierTapMonitor.isPressedAlone(flags: [.maskControl], keyCode: rightControl, modifier: .leftControl))
        XCTAssertNil(ModifierTapMonitor.isPressedAlone(flags: [.maskControl], keyCode: leftControl, modifier: .rightControl))
    }

    func testOtherModifierKeysAreIgnored() {
        XCTAssertNil(ModifierTapMonitor.isPressedAlone(flags: [.maskShift], keyCode: leftShift, modifier: .leftControl))
    }

    /// Control pressed while Shift is held is not a press on its own
    func testPressWithAnotherModifierHeldIsNotAlone() {
        XCTAssertEqual(
            ModifierTapMonitor.isPressedAlone(flags: [.maskControl, .maskShift], keyCode: leftControl, modifier: .leftControl),
            false
        )
        XCTAssertEqual(
            ModifierTapMonitor.isPressedAlone(flags: [.maskControl, .maskCommand], keyCode: leftControl, modifier: .leftControl),
            false
        )
    }

    /// Non-modifier flags (Caps Lock, fn, numeric pad, and so on) do not affect the decision
    func testNonModifierFlagsAreIgnored() {
        XCTAssertEqual(
            ModifierTapMonitor.isPressedAlone(flags: [.maskControl, .maskAlphaShift, .maskNonCoalesced], keyCode: leftControl, modifier: .leftControl),
            true
        )
    }

    func testOffNeverMatches() {
        XCTAssertNil(ModifierTapMonitor.isPressedAlone(flags: [.maskControl], keyCode: leftControl, modifier: .off))
    }

    // MARK: Device-specific bits (left and right)

    private func flags(_ raw: UInt64) -> CGEventFlags { CGEventFlags(rawValue: raw) }
    private let shift: UInt64 = 0x20000
    private let leftShiftBit: UInt64 = 0x2
    private let rightShiftBit: UInt64 = 0x4

    func testDeviceBitsIdentifyTheMonitoredSide() {
        XCTAssertEqual(ModifierTapMonitor.isPressedAlone(flags: flags(shift | leftShiftBit), keyCode: leftShift, modifier: .leftShift), true)
        XCTAssertEqual(ModifierTapMonitor.isPressedAlone(flags: flags(0), keyCode: leftShift, modifier: .leftShift), false)
    }

    /// Releasing left Shift while right Shift is held keeps the Shift flag set, but the device bit reveals the release
    func testReleaseWhileSiblingHeldIsDetected() {
        XCTAssertEqual(
            ModifierTapMonitor.isPressedAlone(flags: flags(shift | rightShiftBit), keyCode: leftShift, modifier: .leftShift),
            false
        )
    }

    /// Pressing left Shift while right Shift is held is not a press on its own
    func testPressWhileSiblingHeldIsNotAlone() {
        XCTAssertEqual(
            ModifierTapMonitor.isPressedAlone(flags: flags(shift | leftShiftBit | rightShiftBit), keyCode: leftShift, modifier: .leftShift),
            false
        )
    }

    func testPressWithOtherFamilyHeldIsNotAloneWithDeviceBits() {
        let control: UInt64 = 0x40000
        let leftControlBit: UInt64 = 0x1
        XCTAssertEqual(
            ModifierTapMonitor.isPressedAlone(flags: flags(shift | leftShiftBit | control | leftControlBit), keyCode: leftShift, modifier: .leftShift),
            false
        )
    }

    /// Without device bits the family flag decides, as before
    func testFallsBackToFamilyFlagsWithoutDeviceBits() {
        XCTAssertEqual(ModifierTapMonitor.isPressedAlone(flags: [.maskShift], keyCode: leftShift, modifier: .leftShift), true)
        XCTAssertEqual(ModifierTapMonitor.isPressedAlone(flags: [.maskShift, .maskControl], keyCode: leftShift, modifier: .leftShift), false)
    }

    func testDeviceMasksAreUniqueAndCoverAllKeys() {
        let masks = ModifierKey.allCases.compactMap { $0.deviceMask }
        XCTAssertEqual(masks.count, ModifierKey.allCases.count - 1)
        XCTAssertEqual(Set(masks).count, masks.count)
        XCTAssertEqual(ModifierKey.leftControl.deviceMask, 0x1)
        XCTAssertEqual(ModifierKey.rightControl.deviceMask, 0x2000)
    }

    func testEverySideMapsToItsFamilyMask() {
        XCTAssertEqual(ModifierKey.leftControl.flagMask, .maskControl)
        XCTAssertEqual(ModifierKey.rightControl.flagMask, .maskControl)
        XCTAssertEqual(ModifierKey.leftShift.flagMask, .maskShift)
        XCTAssertEqual(ModifierKey.rightShift.flagMask, .maskShift)
        XCTAssertEqual(ModifierKey.leftOption.flagMask, .maskAlternate)
        XCTAssertEqual(ModifierKey.rightOption.flagMask, .maskAlternate)
        XCTAssertEqual(ModifierKey.leftCommand.flagMask, .maskCommand)
        XCTAssertEqual(ModifierKey.rightCommand.flagMask, .maskCommand)
        XCTAssertEqual(ModifierKey.off.flagMask, [])
    }
}
