import XCTest
import BlipCore
@testable import Blip

final class SettingsTests: XCTestCase {
    private let suiteName = "com.dominion525.blip.tests.settings"
    private var defaults: UserDefaults!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultsWhenNothingIsStored() {
        XCTAssertEqual(store.effect, .spotlight)
        XCTAssertEqual(store.doubleTapModifier, .leftControl)
    }

    func testEffectRoundTrips() {
        for effect in Effect.allCases {
            store.effect = effect
            XCTAssertEqual(store.effect, effect)
            XCTAssertEqual(defaults.string(forKey: SettingsStore.Key.effect), effect.rawValue)
        }
    }

    func testDoubleTapModifierRoundTrips() {
        for key in ModifierKey.allCases {
            store.doubleTapModifier = key
            XCTAssertEqual(store.doubleTapModifier, key)
            XCTAssertEqual(defaults.string(forKey: SettingsStore.Key.doubleTapModifier), key.rawValue)
        }
    }

    func testDismissalDefaultsToTheConfiguredDuration() {
        XCTAssertEqual(store.dismissal, .after(Config.autoHideSeconds))
    }

    func testDismissalRoundTripsEveryStepInRange() {
        var seconds = SettingsStore.Dismissal.range.lowerBound
        while seconds <= SettingsStore.Dismissal.range.upperBound {
            store.dismissal = .after(seconds)
            XCTAssertEqual(store.dismissal, .after(seconds))
            seconds += SettingsStore.Dismissal.step
        }
    }

    /// Waiting to be found is stored as zero seconds, which no duration in range can collide with
    func testWaitingToBeFoundRoundTrips() {
        store.dismissal = .whenFound
        XCTAssertEqual(store.dismissal, .whenFound)
        XCTAssertEqual(defaults.double(forKey: SettingsStore.Key.autoHideSeconds), 0)
    }

    func testDurationsOutsideTheRangeFallBackToTheDefault() {
        for seconds in [-1.0, 0.05, 5.1, 600.0] {
            defaults.set(seconds, forKey: SettingsStore.Key.autoHideSeconds)
            XCTAssertEqual(store.dismissal, .after(Config.autoHideSeconds), "\(seconds) is not offered")
        }
    }

    /// Values from older versions or corrupted values fall back to the defaults
    func testUnknownStoredValuesFallBackToDefaults() {
        defaults.set("ripple", forKey: SettingsStore.Key.effect)
        defaults.set("control", forKey: SettingsStore.Key.doubleTapModifier)
        XCTAssertEqual(store.effect, .spotlight)
        XCTAssertEqual(store.doubleTapModifier, .leftControl)
    }

    func testWrongTypeStoredValuesFallBackToDefaults() {
        defaults.set(42, forKey: SettingsStore.Key.effect)
        defaults.set(true, forKey: SettingsStore.Key.doubleTapModifier)
        XCTAssertEqual(store.effect, .spotlight)
        XCTAssertEqual(store.doubleTapModifier, .leftControl)
    }

    func testStoresAreIndependentPerDefaults() {
        let otherSuite = "com.dominion525.blip.tests.settings.other"
        let other = UserDefaults(suiteName: otherSuite)!
        other.removePersistentDomain(forName: otherSuite)
        defer { other.removePersistentDomain(forName: otherSuite) }
        let otherStore = SettingsStore(defaults: other)

        store.effect = .zoom
        XCTAssertEqual(otherStore.effect, .spotlight)
    }
}
