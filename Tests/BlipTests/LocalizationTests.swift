import XCTest
import BlipCore
@testable import Blip

final class LocalizationTests: XCTestCase {
    private func strings(for localization: String) throws -> [String: String] {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: localization),
            "\(localization).lproj/Localizable.strings not found"
        )
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
    }

    func testEnglishAndJapaneseHaveTheSameKeys() throws {
        let en = try strings(for: "en")
        let ja = try strings(for: "ja")
        XCTAssertEqual(Set(en.keys), Set(ja.keys))
        XCTAssertFalse(en.isEmpty)
    }

    func testNoTranslationIsEmpty() throws {
        for localization in ["en", "ja"] {
            for (key, value) in try strings(for: localization) {
                XCTAssertFalse(value.isEmpty, "\(localization): \(key)")
            }
        }
    }

    /// Every key resolves (none comes back as the key itself)
    func testEveryKeyResolves() throws {
        for key in try strings(for: "en").keys {
            XCTAssertNotEqual(L(key), key, key)
        }
    }

    func testUnknownKeyFallsBackToKey() {
        XCTAssertEqual(L("no.such.key"), "no.such.key")
    }

    /// Every enum case has a string
    func testEffectAndModifierNamesAreCovered() throws {
        let keys = Set(try strings(for: "en").keys)
        for effect in BlipCore.Effect.allCases {
            XCTAssertTrue(keys.contains("effect.\(effect.rawValue)"), effect.rawValue)
        }
        for key in BlipCore.ModifierKey.allCases {
            XCTAssertTrue(keys.contains("modifier.\(key.rawValue)"), key.rawValue)
        }
    }
}
