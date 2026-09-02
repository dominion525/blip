// Modifier keys available for the double-tap trigger, left and right told apart.
// Used by the settings pop-up and as the UserDefaults value (rawValue).

public enum ModifierKey: String, CaseIterable {
    case off
    case leftControl
    case rightControl
    case leftShift
    case rightShift
    case leftOption
    case rightOption
    case leftCommand
    case rightCommand

    /// Name shown in the settings window
    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .leftControl: return "Left Control"
        case .rightControl: return "Right Control"
        case .leftShift: return "Left Shift"
        case .rightShift: return "Right Shift"
        case .leftOption: return "Left Option"
        case .rightOption: return "Right Option"
        case .leftCommand: return "Left Command"
        case .rightCommand: return "Right Command"
        }
    }

    /// Key code carried by flagsChanged events. Left and right differ. Nil for off
    public var keyCode: Int64? {
        switch self {
        case .off: return nil
        case .leftControl: return 59
        case .rightControl: return 62
        case .leftShift: return 56
        case .rightShift: return 60
        case .leftOption: return 58
        case .rightOption: return 61
        case .leftCommand: return 55
        case .rightCommand: return 54
        }
    }

    /// Used when nothing is stored or the stored value is unknown
    public static let `default`: ModifierKey = .leftControl
}
