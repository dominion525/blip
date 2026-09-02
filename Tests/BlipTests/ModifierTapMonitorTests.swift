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
