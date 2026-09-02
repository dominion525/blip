// Settings persisted in UserDefaults: keys and defaults live here.
// The hotkey is not here because KeyboardShortcuts stores it in UserDefaults itself.

import BlipCore
import Foundation

/// Reads and writes settings. The UserDefaults instance is injectable (for tests)
final class SettingsStore {
    private let defaults: UserDefaults

    enum Key {
        static let doubleTapModifier = "doubleTapModifier"
        static let effect = "effect"
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Modifier key whose double-tap shows the effect. Off disables the double-tap
    var doubleTapModifier: ModifierKey {
        get { ModifierKey(rawValue: defaults.string(forKey: Key.doubleTapModifier) ?? "") ?? ModifierKey.default }
        set { defaults.set(newValue.rawValue, forKey: Key.doubleTapModifier) }
    }

    /// Selected effect. Falls back to the default when unset or unknown
    var effect: Effect {
        get { Effect(rawValue: defaults.string(forKey: Key.effect) ?? "") ?? Effect.default }
        set { defaults.set(newValue.rawValue, forKey: Key.effect) }
    }
}

/// Entry point for the app itself, backed by the standard UserDefaults
enum Settings {
    static let store = SettingsStore(defaults: .standard)

    static var doubleTapModifier: ModifierKey {
        get { store.doubleTapModifier }
        set { store.doubleTapModifier = newValue }
    }

    static var effect: Effect {
        get { store.effect }
        set { store.effect = newValue }
    }
}
