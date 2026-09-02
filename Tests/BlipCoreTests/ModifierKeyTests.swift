import XCTest
@testable import BlipCore

final class ModifierKeyTests: XCTestCase {
    func testAllCasesInMenuOrder() {
        XCTAssertEqual(ModifierKey.allCases, [
            .off,
            .leftControl, .rightControl,
            .leftShift, .rightShift,
            .leftOption, .rightOption,
            .leftCommand, .rightCommand,
        ])
    }

    func testRawValueRoundTrip() {
        for key in ModifierKey.allCases {
            XCTAssertEqual(ModifierKey(rawValue: key.rawValue), key)
        }
    }

    func testDefaultIsLeftControl() {
        XCTAssertEqual(ModifierKey.default, .leftControl)
    }

    func testOffHasNoKeyCode() {
        XCTAssertNil(ModifierKey.off.keyCode)
    }

    /// Left and right keys have distinct key codes with no duplicates
    func testKeyCodesAreUniquePerKey() {
        let codes = ModifierKey.allCases.compactMap { $0.keyCode }
        XCTAssertEqual(codes.count, ModifierKey.allCases.count - 1)
        XCTAssertEqual(Set(codes).count, codes.count)
    }

    func testKnownKeyCodes() {
        XCTAssertEqual(ModifierKey.leftControl.keyCode, 59)
        XCTAssertEqual(ModifierKey.rightControl.keyCode, 62)
        XCTAssertEqual(ModifierKey.leftCommand.keyCode, 55)
        XCTAssertEqual(ModifierKey.rightCommand.keyCode, 54)
    }
}
