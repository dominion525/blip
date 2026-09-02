// Detects modifier double-taps with a listen-only CGEvent tap.
// Left and right keys are told apart by the key code and device-specific bits of flagsChanged events (NSEvent.modifierFlags cannot).
// Requires Input Monitoring. When not granted, the OS dialog is requested and the monitor keeps checking until it is, then creates the tap.
// Permission is re-checked after that too: revoking it tears the tap down and returns to waiting; granting it again rebuilds the tap.
// A failed tap creation is treated as waiting as well and retried on the next check.

import AppKit
import BlipCore

/// The interface AppDelegate uses to drive the double-tap monitor (tests substitute a fake)
protocol ModifierTapMonitoring: AnyObject {
    var status: ModifierTapMonitor.Status { get }
    func setModifier(_ modifier: ModifierKey)
}

/// The minimal event tap operations. CGEventTapHandle is the real one; tests inject a fake
protocol EventTap: AnyObject {
    var isEnabled: Bool { get }
    func enable()
    func invalidate()
}

/// A listen-only tap from CGEvent.tapCreate that receives flagsChanged only
final class CGEventTapHandle: EventTap {
    private let port: CFMachPort
    private let source: CFRunLoopSource

    /// Nil when creation fails (no permission, or an OS-side reason)
    static func make(handler: @escaping (CGEventType, CGEvent) -> Void) -> EventTap? {
        CGEventTapHandle(handler: handler)
    }

    private init?(handler: @escaping (CGEventType, CGEvent) -> Void) {
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        // The callback is a C function, so the handler travels in a box passed as refcon
        let box = HandlerBox(handler: handler)
        let refcon = Unmanaged.passRetained(box).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                if let refcon = refcon {
                    Unmanaged<HandlerBox>.fromOpaque(refcon).takeUnretainedValue().handler(type, event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            Unmanaged<HandlerBox>.fromOpaque(refcon).release()
            return nil
        }
        self.port = port
        self.source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        self.box = box
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    private let box: HandlerBox
    private final class HandlerBox {
        let handler: (CGEventType, CGEvent) -> Void
        init(handler: @escaping (CGEventType, CGEvent) -> Void) { self.handler = handler }
    }

    var isEnabled: Bool { CGEvent.tapIsEnabled(tap: port) }

    func enable() {
        CGEvent.tapEnable(tap: port, enable: true)
    }

    func invalidate() {
        CGEvent.tapEnable(tap: port, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        CFMachPortInvalidate(port)
        Unmanaged.passUnretained(box).release()
    }
}

final class ModifierTapMonitor: ModifierTapMonitoring {
    enum Status: Equatable {
        /// The watched modifier is off
        case off
        /// No permission, or the tap could not be created. Checked periodically to recover
        case waitingForPermission
        /// The tap is alive
        case active
    }

    typealias TapFactory = (@escaping (CGEventType, CGEvent) -> Void) -> EventTap?

    /// Check interval while waiting for permission, and the interval for spotting revocation while active, in seconds
    static let waitingCheckInterval: TimeInterval = 1.0
    static let activeCheckInterval: TimeInterval = 5.0

    private let interval: TimeInterval
    private let onDoubleTap: () -> Void
    private let permissionCheck: () -> Bool
    private let requestPermission: () -> Void
    private let makeTap: TapFactory
    private var modifier: ModifierKey = .off
    private var tracker: DoubleTapTracker
    private var tap: EventTap?
    private var checkTimer: Timer?
    private var hasRequestedPermission = false
    private(set) var status: Status = .off

    /// Whether Input Monitoring is granted
    static var hasPermission: Bool {
        CGPreflightListenEventAccess()
    }

    /// Opens the Input Monitoring pane in System Settings
    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }

    /// permissionCheck, requestPermission, and makeTap are the OS touch points. The defaults are real; tests inject fakes
    init(
        interval: TimeInterval,
        permissionCheck: @escaping () -> Bool = { ModifierTapMonitor.hasPermission },
        requestPermission: @escaping () -> Void = { CGRequestListenEventAccess() },
        makeTap: @escaping TapFactory = CGEventTapHandle.make,
        onDoubleTap: @escaping () -> Void
    ) {
        self.interval = interval
        self.permissionCheck = permissionCheck
        self.requestPermission = requestPermission
        self.makeTap = makeTap
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
        if status == .off {
            status = .waitingForPermission
            hasRequestedPermission = false
        }
        reconcile()
    }

    func stop() {
        checkTimer?.invalidate()
        checkTimer = nil
        tearDownTap()
        status = .off
    }

    // MARK: Permission and tap lifecycle

    /// Reconciles permission with the tap: creates or tears it down as needed. Called periodically from the timer
    func reconcile() {
        guard modifier != .off else { return }
        let granted = permissionCheck()
        if !granted {
            if tap != nil {
                NSLog("Blip: input monitoring permission lost; waiting for it")
                tearDownTap()
            }
            status = .waitingForPermission
            if !hasRequestedPermission {
                NSLog("Blip: input monitoring permission not granted; requesting")
                requestPermission()
                hasRequestedPermission = true
            }
        } else if let tap = tap {
            // Re-enable a tap the OS disabled (for example after a slow callback)
            if !tap.isEnabled {
                tap.enable()
            }
            status = .active
        } else if installTap() {
            status = .active
            hasRequestedPermission = false
        } else {
            NSLog("Blip: event tap could not be created; retrying")
            status = .waitingForPermission
        }
        scheduleCheck()
    }

    private func installTap() -> Bool {
        guard let tap = makeTap({ [weak self] type, event in
            self?.handle(type: type, event: event)
        }) else { return false }
        self.tap = tap
        NSLog("Blip: modifier double-tap enabled (%@)", modifier.rawValue)
        return true
    }

    private func tearDownTap() {
        tap?.invalidate()
        tap = nil
    }

    private func scheduleCheck() {
        checkTimer?.invalidate()
        let seconds = status == .active ? Self.activeCheckInterval : Self.waitingCheckInterval
        let timer = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
            self?.reconcile()
        }
        RunLoop.main.add(timer, forMode: .common)
        checkTimer = timer
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            tap?.enable()
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
