// Settings persisted in UserDefaults: keys and defaults live here.
// The hotkey is not here because KeyboardShortcuts stores it in UserDefaults itself.

import BlipCore
import Foundation

enum Settings {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let controlDoubleTapEnabled = "controlDoubleTapEnabled"
        static let effect = "effect"
    }

    /// Whether a Control double-tap shows the spotlight. On by default
    static var controlDoubleTapEnabled: Bool {
        get { defaults.object(forKey: Key.controlDoubleTapEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.controlDoubleTapEnabled) }
    }

    /// Selected effect. Falls back to the default when unset or unknown
    static var effect: Effect {
        get { Effect(rawValue: defaults.string(forKey: Key.effect) ?? "") ?? Effect.default }
        set { defaults.set(newValue.rawValue, forKey: Key.effect) }
    }
}
