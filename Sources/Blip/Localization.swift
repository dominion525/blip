// String lookup. Keys resolve against Resources/<lang>.lproj/Localizable.strings.
// The display language follows macOS settings (per-app language in System Settings and the -AppleLanguages launch argument both apply).

import BlipCore
import Foundation

/// Returns the display string for a Localizable.strings key, or the key itself when it is missing
func L(_ key: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: .module, value: key, comment: "")
}

extension Effect {
    var localizedName: String { L("effect.\(rawValue)") }
}

extension ModifierKey {
    var localizedName: String { L("modifier.\(rawValue)") }
}
