// String lookup. Keys resolve against Resources/<lang>.lproj/Localizable.strings.
// This is an Xcode app target, so the tables land in Contents/Resources/<lang>.lproj and Bundle.main finds them.
// The display language follows macOS settings (per-app language in System Settings and the -AppleLanguages launch argument both apply).

import BlipCore
import Foundation

/// Returns the display string for a Localizable.strings key, or the key itself when it is missing
func L(_ key: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
}

extension Effect {
    var localizedName: String { L("effect.\(rawValue)") }
}

extension ModifierKey {
    var localizedName: String { L("modifier.\(rawValue)") }
}
