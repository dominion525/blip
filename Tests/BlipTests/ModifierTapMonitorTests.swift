import XCTest
import BlipCore
@testable import Blip

final class ModifierTapMonitorTests: XCTestCase {
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
