import XCTest
@testable import BlipCore

final class EffectTests: XCTestCase {
    func testAllCasesInMenuOrder() {
        XCTAssertEqual(Effect.allCases, [.spotlight, .zoom, .flash, .focusLines])
    }

    func testRawValueRoundTrip() {
        for effect in Effect.allCases {
            XCTAssertEqual(Effect(rawValue: effect.rawValue), effect)
        }
    }

    func testUnknownRawValueIsNil() {
        XCTAssertNil(Effect(rawValue: "ripple"))
    }

    func testDefaultIsSpotlight() {
        XCTAssertEqual(Effect.default, .spotlight)
    }

    func testDisplayNamesAreUnique() {
        let names = Effect.allCases.map { $0.displayName }
        XCTAssertEqual(Set(names).count, names.count)
    }
}
