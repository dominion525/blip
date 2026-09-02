// Detects modifier double-taps with a listen-only CGEvent tap.
// Left and right keys are told apart by the key code of flagsChanged events (NSEvent.modifierFlags cannot).
// Requires Input Monitoring. When not granted, the OS dialog is requested and permission is checked every second until it is, then the tap is created.

import AppKit
import BlipCore

/// The interface AppDelegate uses to drive the double-tap monitor (tests substitute a fake)
protocol ModifierTapMonitoring: AnyObject {
    func setModifier(_ modifier: ModifierKey)
}

final class ModifierTapMonitor: ModifierTapMonitoring {
    private let interval: TimeInterval
    private let onDoubleTap: () -> Void
    private var modifier: ModifierKey = .off
    private var tracker: DoubleTapTracker
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?

    /// Whether Input Monitoring is granted
    static var hasPermission: Bool {
        CGPreflightListenEventAccess()
    }

    /// Opens the Input Monitoring pane in System Settings
    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }

    init(interval: TimeInterval, onDoubleTap: @escaping () -> Void) {
        self.interval = interval
        self.onDoubleTap = onDoubleTap
        self.tracker = DoubleTapTracker(interval: interval)
    }

    /// Changes the watched modifier. Off stops monitoring
    func setModifier(_ modifier: ModifierKey) {
        self.modifier = modifier
        tracker = DoubleTapTracker(interval: interval)
        if modifier == .off {
            stop()
            NSLog("Blip: modifier double-tap disabled")
            return
        }
        startIfNeeded()
    }

    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        tap = nil
    }

    // MARK: Permission and tap

    private func startIfNeeded() {
        guard tap == nil, permissionTimer == nil else { return }
        if Self.hasPermission {
            installTap()
            return
        }
        NSLog("Blip: input monitoring permission not granted; requesting")
        CGRequestListenEventAccess()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            guard Self.hasPermission else { return }
            timer.invalidate()
            self.permissionTimer = nil
            self.installTap()
        }
    }

    private func installTap() {
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                if let refcon = refcon {
                    Unmanaged<ModifierTapMonitor>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            NSLog("Blip: CGEvent.tapCreate failed")
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = source
        NSLog("Blip: modifier double-tap enabled (%@)", modifier.rawValue)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // Re-enable the tap when the OS disables it (for example after a slow callback)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }
        guard type == .flagsChanged else { return }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard let isDown = Self.isPressedAlone(flags: event.flags, keyCode: keyCode, modifier: modifier) else { return }
        // Log the raw flags so the presence of the left/right device bits can be verified
        NSLog("Blip: modifier %@ keyCode %lld flags 0x%llx -> %@", modifier.rawValue, keyCode, event.flags.rawValue, isDown ? "down" : "up")
        if tracker.update(isDown: isDown, at: ProcessInfo.processInfo.systemUptime) {
            NSLog("Blip: modifier double-tap (%@)", modifier.rawValue)
            onDoubleTap()
        }
    }
}

extension ModifierTapMonitor {
    /// All device-specific bits that identify left and right keys (NX_DEVICE*KEYMASK in IOKit's IOLLEvent.h)
    static let allDeviceMasks: UInt64 = ModifierKey.allCases.compactMap { $0.deviceMask }.reduce(0, |)

    /// Interprets a flagsChanged event as a press or release of the watched key on its own.
    /// Nil when the key code is not the watched key. Otherwise true when the key is down with no other modifier held, false otherwise.
    /// A press with another modifier held yields false, so combinations like ⌃C never count as a press.
    /// Left and right are told apart by the device-specific bits. Without them, releasing the watched key (say left Shift) while its
    /// sibling (right Shift) is held leaves the Shift flag set and the release goes unnoticed. Events without device bits fall back to the family flag
    static func isPressedAlone(flags: CGEventFlags, keyCode: Int64, modifier: ModifierKey) -> Bool? {
        guard let targetKeyCode = modifier.keyCode, let deviceMask = modifier.deviceMask, keyCode == targetKeyCode else { return nil }
        let families: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand]
        let familiesHeld = flags.intersection(families)
        let deviceBits = flags.rawValue & allDeviceMasks
        if deviceBits != 0 || familiesHeld.isEmpty {
            let selfDown = deviceBits & deviceMask != 0
            let othersDown = deviceBits & ~deviceMask != 0
            return selfDown && !othersDown
        }
        return familiesHeld == modifier.flagMask
    }
}

extension ModifierKey {
    /// The device-specific bit for this key alone. Nil for off
    var deviceMask: UInt64? {
        switch self {
        case .off: return nil
        case .leftControl: return 0x0000_0001
        case .rightControl: return 0x0000_2000
        case .leftShift: return 0x0000_0002
        case .rightShift: return 0x0000_0004
        case .leftCommand: return 0x0000_0008
        case .rightCommand: return 0x0000_0010
        case .leftOption: return 0x0000_0020
        case .rightOption: return 0x0000_0040
        }
    }
}

extension ModifierKey {
    /// The CGEventFlags family bit set while this key is down. Does not distinguish left from right
    var flagMask: CGEventFlags {
        switch self {
        case .off: return []
        case .leftControl, .rightControl: return .maskControl
        case .leftShift, .rightShift: return .maskShift
        case .leftOption, .rightOption: return .maskAlternate
        case .leftCommand, .rightCommand: return .maskCommand
        }
    }
}
