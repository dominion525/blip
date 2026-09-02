// The cursor highlight effects. Used by the settings pop-up and as the UserDefaults value (rawValue).

public enum Effect: String, CaseIterable {
    case spotlight
    case zoom
    case flash
    case focusLines

    /// Name shown in the settings window
    public var displayName: String {
        switch self {
        case .spotlight: return "Spotlight"
        case .zoom: return "Zoom"
        case .flash: return "Flash"
        case .focusLines: return "Focus Lines"
        }
    }

    /// Used when nothing is stored or the stored value is unknown
    public static let `default`: Effect = .spotlight
}
