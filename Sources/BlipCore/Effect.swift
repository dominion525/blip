// The cursor highlight effects. Used by the settings pop-up and as the UserDefaults value (rawValue).

public enum Effect: String, CaseIterable {
    case spotlight
    case zoom
    case flash
    case focusLines

    /// Used when nothing is stored or the stored value is unknown
    public static let `default`: Effect = .spotlight
}
