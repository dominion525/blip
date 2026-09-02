// Blip: a menu bar utility that highlights the mouse cursor
//
// Layout (least dependent first)
//   Config            Drawing and timing defaults. The hotkey and effect choice live in the settings window (UserDefaults)
//   Geometry          Coordinate conversion and display matching (BlipCore/Geometry.swift, pure functions)
//   SpotlightView     Draws the dim layer and the spot
//   OverlayWindow     Borderless, click-through window shown on every Space
//   OverlayController Per-display windows, cursor tracking, auto-hide
//   DoubleTapTracker  Modifier double-tap detection (BlipCore/DoubleTap.swift, pure state machine)
//   KeyboardShortcuts.Name  Hotkey definition (registration and the recorder UI come from the library)
//   ModifierTapMonitor Modifier double-tap via an event tap (ModifierTapMonitor.swift)
//   SettingsWindowController Settings window (SettingsWindowController.swift)
//   Settings          UserDefaults-backed settings (Settings.swift)
//   AppDelegate       Status item and wiring of the parts

import AppKit
import BlipCore
import KeyboardShortcuts

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
    /// Cursor tracking interval, in seconds
    static let trackingInterval: TimeInterval = 1.0 / 60.0
    /// Maximum seconds between the two presses of a modifier double-tap. Nil disables it; which key is set in the settings window
    static let doubleTapInterval: TimeInterval? = 0.3
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

// MARK: - Hotkey

extension KeyboardShortcuts.Name {
    /// The hotkey that shows the effect. Defaults to ⌥⌘Z; changes made in the settings window persist in UserDefaults
    static let showSpotlight = Self("showSpotlight", initial: .init(.z, modifiers: [.option, .command]))
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let overlay = OverlayController()
    private lazy var modifierTap = ModifierTapMonitor(interval: Config.doubleTapInterval ?? 0.3) { [weak self] in
        self?.overlay.toggle()
    }
    private lazy var settings = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpMainMenu()
        setUpStatusItem()

        KeyboardShortcuts.onKeyDown(for: .showSpotlight) { [weak self] in
            self?.overlay.toggle()
        }
        NSLog("Blip: hotkey %@", KeyboardShortcuts.getShortcut(for: .showSpotlight).map { String(describing: $0) } ?? "(none)")

        settings.onDoubleTapModifierChanged = { [weak self] modifier in
            self?.setDoubleTap(modifier: modifier)
        }
        setDoubleTap(modifier: Settings.doubleTapModifier)
    }

    /// Switches the modifier watched for double-taps. Called at launch and from the settings window
    private func setDoubleTap(modifier: ModifierKey) {
        guard Config.doubleTapInterval != nil else {
            modifierTap.setModifier(.off)
            return
        }
        modifierTap.setModifier(modifier)
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

    /// Icon for the About panel. The bundle has no icon file yet, so the menu bar symbol is passed explicitly
    private var aboutIcon: NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 128, weight: .regular)
            .applying(.init(hierarchicalColor: .controlAccentColor))
        return NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Blip")?
            .withSymbolConfiguration(configuration)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
        if let icon = aboutIcon {
            options[.applicationIcon] = icon
        }
        NSApp.orderFrontStandardAboutPanel(options: options)
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
