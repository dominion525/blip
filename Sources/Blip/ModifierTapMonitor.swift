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
        guard let isDown = Self.isPressedAlone(
            flags: event.flags,
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            modifier: modifier
        ) else { return }
        if tracker.update(isDown: isDown, at: ProcessInfo.processInfo.systemUptime) {
            NSLog("Blip: modifier double-tap (%@)", modifier.rawValue)
            onDoubleTap()
        }
    }
}

extension ModifierTapMonitor {
    /// Interprets a flagsChanged event as a press or release of the watched key on its own.
    /// Nil when the key code is not the watched key. Otherwise true when the key is down with no other modifier held, false otherwise.
    /// A press with another modifier held yields false, so combinations like ⌃C never count as a press
    static func isPressedAlone(flags: CGEventFlags, keyCode: Int64, modifier: ModifierKey) -> Bool? {
        guard let targetKeyCode = modifier.keyCode, keyCode == targetKeyCode else { return nil }
        let allModifiers: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand]
        return flags.intersection(allModifiers) == modifier.flagMask
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
