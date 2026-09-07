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
        static let autoHideSeconds = "autoHideSeconds"
    }

    /// What the effect does about ending itself
    enum Dismissal: Equatable {
        /// Ends on its own after this many seconds
        case after(TimeInterval)
        /// Stays until its user shows they have found the cursor
        case whenFound

        /// The range the settings window offers, in seconds
        public static let range: ClosedRange<TimeInterval> = 0.1...5.0
        static let step: TimeInterval = 0.1
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

    /// How the effect ends. Stored as seconds, with zero standing for waiting to be found;
    /// an unset or out-of-range value falls back to the default rather than to something unusable
    var dismissal: Dismissal {
        get {
            guard defaults.object(forKey: Key.autoHideSeconds) != nil else { return .after(Config.autoHideSeconds) }
            let seconds = defaults.double(forKey: Key.autoHideSeconds)
            if seconds == 0 { return .whenFound }
            guard Dismissal.range.contains(seconds) else { return .after(Config.autoHideSeconds) }
            return .after(seconds)
        }
        set {
            switch newValue {
            case .after(let seconds): defaults.set(seconds, forKey: Key.autoHideSeconds)
            case .whenFound: defaults.set(0, forKey: Key.autoHideSeconds)
            }
        }
    }
}

/// Entry point for the app itself, backed by the standard UserDefaults
enum Settings {
    static let store = SettingsStore(defaults: .standard)
}
