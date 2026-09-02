// Settings persisted in UserDefaults: keys and defaults live here.
// The hotkey is not here because KeyboardShortcuts stores it in UserDefaults itself.

import BlipCore
import Foundation

enum Settings {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let doubleTapModifier = "doubleTapModifier"
        static let effect = "effect"
    }

    /// Modifier key whose double-tap shows the effect. Off disables the double-tap
    static var doubleTapModifier: ModifierKey {
        get { ModifierKey(rawValue: defaults.string(forKey: Key.doubleTapModifier) ?? "") ?? ModifierKey.default }
        set { defaults.set(newValue.rawValue, forKey: Key.doubleTapModifier) }
    }

    /// Selected effect. Falls back to the default when unset or unknown
    static var effect: Effect {
        get { Effect(rawValue: defaults.string(forKey: Key.effect) ?? "") ?? Effect.default }
        set { defaults.set(newValue.rawValue, forKey: Key.effect) }
    }
}
