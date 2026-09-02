// Blip: a menu bar utility that highlights the mouse cursor
//
// Layout (least dependent first)
//   Config            Tunable defaults; edit only this to adjust
//   Geometry          Coordinate conversion and display matching (BlipCore/Geometry.swift, pure functions)
//   SpotlightView     Draws the dim layer and the spot
//   OverlayWindow     Borderless, click-through window shown on every Space
//   OverlayController Per-display windows, cursor tracking, auto-hide
//   DoubleTapTracker  Modifier double-tap detection (BlipCore/DoubleTap.swift, pure state machine)
//   HotKeyManager     Global hotkey via Carbon RegisterEventHotKey
//   ModifierTapDetector Polls modifier state to detect a double-tap
//   SettingsWindowController Settings window
//   AppDelegate       Status item and wiring of the parts

import AppKit
import BlipCore
import Carbon.HIToolbox
import ServiceManagement

// MARK: - Config

enum Config {
    /// Radius of the spot (the hole), in points
    static let spotRadius: CGFloat = 110
    /// Opacity of the dim layer: 0 transparent, 1 solid black
    static let dimOpacity: CGFloat = 0.55
    /// Ring color
    static let ringColor: NSColor = .systemYellow
    /// Ring line width, in points
    static let ringWidth: CGFloat = 4
    /// Seconds until the effect hides itself. Nil switches to toggle mode, where pressing the hotkey again hides it
    static let autoHideSeconds: TimeInterval? = 1.2
    /// Hotkey key code (default Z)
    static let hotKeyCode: UInt32 = UInt32(kVK_ANSI_Z)
    /// Hotkey modifiers (default ⌥⌘). controlKey and shiftKey can be OR-ed in
    static let hotKeyModifiers: UInt32 = UInt32(optionKey | cmdKey)
    /// Cursor tracking interval, in seconds
    static let trackingInterval: TimeInterval = 1.0 / 60.0
    /// Also show on a Control double-tap. Maximum seconds between the two presses; nil disables it
    static let controlDoubleTapInterval: TimeInterval? = 0.3
    /// Modifier polling interval, in seconds
    static let modifierPollInterval: TimeInterval = 1.0 / 60.0
}

// MARK: - SpotlightView

/// Draws the dim layer and the spot. One per window, filling it as the contentView.
final class SpotlightView: NSView {
    /// Spot center in view coordinates. Nil dims the whole view without a hole (the cursor is on another screen)
    var spot: CGPoint? {
        didSet {
            if spot != oldValue { needsDisplay = true }
        }
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // 1. Fill everything with translucent black
        ctx.setFillColor(NSColor.black.withAlphaComponent(Config.dimOpacity).cgColor)
        ctx.fill(bounds)

        guard let center = spot else { return }
        let hole = Geometry.holeRect(center: center, radius: Config.spotRadius)

        // 2. Punch the hole with the .clear blend mode (erase the dim so the desktop shows through)
        ctx.setBlendMode(.clear)
        ctx.fillEllipse(in: hole)

        // 3. Back to .normal for the ring. Inset by half the line width so the stroke is centered on the hole's edge
        ctx.setBlendMode(.normal)
        ctx.setStrokeColor(Config.ringColor.cgColor)
        ctx.setLineWidth(Config.ringWidth)
        ctx.strokeEllipse(in: hole.insetBy(dx: Config.ringWidth / 2, dy: Config.ringWidth / 2))
    }
}

// MARK: - OverlayWindow

/// A borderless window covering one screen that passes clicks through and never takes focus
final class OverlayWindow: NSWindow {
    let spotlightView: SpotlightView

    init(screen: NSScreen) {
        spotlightView = SpotlightView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        contentView = spotlightView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Disable AppKit's frame adjustments (such as leaving room for the menu bar) so the window covers the whole screen
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

// MARK: - OverlayController

/// Owns one window per display and handles showing, hiding, cursor tracking, and auto-hide
final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var trackingTimer: Timer?
    private var autoHideTimer: Timer?
    private var lastMouseLocation: CGPoint?
    private(set) var isVisible = false

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Entry point for the hotkey and the menu. In toggle mode (autoHideSeconds nil) it hides while visible; otherwise it shows
    func toggle() {
        if isVisible && Config.autoHideSeconds == nil {
            hide()
        } else {
            show()
        }
    }

    func show() {
        syncWindowsWithScreens()
        updateSpot(force: true)
        for window in windows {
            window.orderFrontRegardless()
        }
        isVisible = true
        startTracking()
        scheduleAutoHide()
        NSLog("Blip: show (%d windows)", windows.count)
    }

    func hide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        trackingTimer?.invalidate()
        trackingTimer = nil
        for window in windows {
            window.orderOut(nil)
        }
        isVisible = false
        NSLog("Blip: hide")
    }

    // MARK: Window management

    /// Compares the current NSScreen.screens with the windows' frames and rebuilds the windows when they differ
    private func syncWindowsWithScreens() {
        let screens = NSScreen.screens
        if Geometry.framesMatch(windows: windows.map { $0.frame }, screens: screens.map { $0.frame }) {
            return
        }
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows = screens.map { OverlayWindow(screen: $0) }
        NSLog("Blip: rebuilt overlay windows for %d screens", windows.count)
    }

    @objc private func screenParametersDidChange() {
        NSLog("Blip: screen parameters changed")
        syncWindowsWithScreens()
        guard isVisible else { return }
        updateSpot(force: true)
        for window in windows {
            window.orderFrontRegardless()
        }
    }

    // MARK: Cursor tracking

    private func startTracking() {
        trackingTimer?.invalidate()
        let timer = Timer(timeInterval: Config.trackingInterval, repeats: true) { [weak self] _ in
            self?.updateSpot(force: false)
        }
        // Without .common the timer pauses while a menu is open
        RunLoop.main.add(timer, forMode: .common)
        trackingTimer = timer
    }

    /// Distributes the cursor position to every window; only the screen under the cursor gets a non-nil spot
    private func updateSpot(force: Bool) {
        let location = NSEvent.mouseLocation
        if !force, let last = lastMouseLocation, last == location { return }
        lastMouseLocation = location
        for window in windows {
            window.spotlightView.spot = Geometry.spotCenter(mouse: location, in: window.frame)
        }
    }

    // MARK: Auto-hide

    private func scheduleAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        guard let seconds = Config.autoHideSeconds else { return }
        let timer = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
            self?.hide()
        }
        RunLoop.main.add(timer, forMode: .common)
        autoHideTimer = timer
    }
}

// MARK: - HotKeyManager

/// Registers a global hotkey with Carbon's RegisterEventHotKey. No accessibility permission is needed.
final class HotKeyManager {
    /// EventHotKeyID.signature, used to confirm the hotkey belongs to this process
    private static let signature: OSType = {
        var value: OSType = 0
        for byte in "blip".utf8 {
            value = (value << 8) | OSType(byte)
        }
        return value
    }()

    private let keyCode: UInt32
    private let modifiers: UInt32
    private let hotKeyID: UInt32
    private let onPress: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(keyCode: UInt32, modifiers: UInt32, id: UInt32 = 1, onPress: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.hotKeyID = id
        self.onPress = onPress
    }

    /// True when registration succeeds.
    /// The InstallEventHandler callback is a C function pointer and cannot capture context,
    /// so a pointer to self is passed as userData and turned back into self inside the handler.
    func register() -> Bool {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()

        let handler: EventHandlerUPP = { _, event, userData in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            var pressedID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &pressedID
            )
            guard status == noErr else { return status }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            return manager.handle(pressedID)
        }

        var status = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, userData, &handlerRef)
        guard status == noErr else {
            NSLog("Blip: InstallEventHandler failed (%d)", status)
            return false
        }

        let id = EventHotKeyID(signature: Self.signature, id: hotKeyID)
        status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            NSLog("Blip: RegisterEventHotKey failed (%d)", status)
            return false
        }
        NSLog("Blip: hotkey registered (keyCode %u, modifiers 0x%x)", keyCode, modifiers)
        return true
    }

    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef = handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    private func handle(_ id: EventHotKeyID) -> OSStatus {
        guard id.signature == Self.signature, id.id == hotKeyID else {
            return OSStatus(eventNotHandledErr)
        }
        onPress()
        return noErr
    }

    deinit {
        unregister()
    }
}

// MARK: - ModifierTapDetector

/// Detects a double-tap of a modifier key on its own.
/// Only polls NSEvent.modifierFlags (the modifiers currently held), so unlike key event monitoring it needs no permission.
final class ModifierTapDetector {
    private let flag: NSEvent.ModifierFlags
    private let pollInterval: TimeInterval
    private let onDoubleTap: () -> Void
    private var tracker: DoubleTapTracker
    private var timer: Timer?
    private var wasDown = false

    init(flag: NSEvent.ModifierFlags, interval: TimeInterval, pollInterval: TimeInterval, onDoubleTap: @escaping () -> Void) {
        self.flag = flag
        self.pollInterval = pollInterval
        self.onDoubleTap = onDoubleTap
        self.tracker = DoubleTapTracker(interval: interval)
    }

    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        NSLog("Blip: modifier double-tap enabled (flag 0x%lx)", flag.rawValue)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let flags = NSEvent.modifierFlags
        // Only the watched modifier held alone counts as a press; combinations like ⌃C do not
        let isDown = flags.intersection(.deviceIndependentFlagsMask) == flag
        if isDown && !wasDown {
            // Log the raw value to see whether bits that tell left from right are present
            NSLog("Blip: modifier down (raw 0x%lx)", flags.rawValue)
        }
        wasDown = isDown
        if tracker.update(isDown: isDown, at: ProcessInfo.processInfo.systemUptime) {
            NSLog("Blip: modifier double-tap")
            onDoubleTap()
        }
    }
}

// MARK: - SettingsWindowController

/// The settings window. Survives closing; the same window comes to the front next time
final class SettingsWindowController: NSWindowController {
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 120),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Blip Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin(_:))

        let stack = NSStackView(views: [launchAtLoginCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        do {
            if sender.state == .on {
                try SMAppService.mainApp.register()
                NSLog("Blip: launch at login enabled")
            } else {
                try SMAppService.mainApp.unregister()
                NSLog("Blip: launch at login disabled")
            }
        } catch {
            NSLog("Blip: launch at login change failed: %@", String(describing: error))
            sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let overlay = OverlayController()
    private var hotKey: HotKeyManager?
    private var modifierTap: ModifierTapDetector?
    private lazy var settings = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpMainMenu()
        setUpStatusItem()

        let hotKey = HotKeyManager(keyCode: Config.hotKeyCode, modifiers: Config.hotKeyModifiers) { [weak self] in
            self?.overlay.toggle()
        }
        if !hotKey.register() {
            NSLog("Blip: hotkey is unavailable; use the menu bar item instead")
        }
        self.hotKey = hotKey

        if let interval = Config.controlDoubleTapInterval {
            let detector = ModifierTapDetector(
                flag: .control,
                interval: interval,
                pollInterval: Config.modifierPollInterval
            ) { [weak self] in
                self?.overlay.toggle()
            }
            detector.start()
            modifierTap = detector
        }
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            if let image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Blip") {
                button.image = image
            } else {
                button.title = "◎"
            }
        }

        let menu = NSMenu()
        let trigger = NSMenuItem(title: "Show Spotlight", action: #selector(triggerSpotlight), keyEquivalent: "")
        trigger.target = self
        menu.addItem(trigger)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let aboutItem = NSMenuItem(title: "About Blip", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Blip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
    }

    /// A minimal main menu so ⌘, and ⌘Q work on the settings window even though the app has no menu bar presence
    private func setUpMainMenu() {
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Blip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func triggerSpotlight() {
        overlay.toggle()
    }

    @objc private func showSettings() {
        settings.show()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
