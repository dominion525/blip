import XCTest
import BlipCore
import KeyboardShortcuts
@testable import Blip

/// Runs the launch sequence (applicationDidFinishLaunching) for real and checks the initial state.
/// The double-tap monitor is replaced with a fake so no permission dialog appears.
@MainActor
final class AppDelegateLaunchTests: XCTestCase {
    private final class FakeModifierTap: ModifierTapMonitoring {
        var received: [ModifierKey] = []
        var status: ModifierTapMonitor.Status = .off
        func setModifier(_ modifier: ModifierKey) {
            received.append(modifier)
            status = modifier == .off ? .off : .active
        }
    }

    private let suiteName = "local.blip.tests.launch"
    private var defaults: UserDefaults!
    private var store: SettingsStore!
    private var fakeTap: FakeModifierTap!
    private var delegate: AppDelegate!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SettingsStore(defaults: defaults)
        fakeTap = FakeModifierTap()
    }

    override func tearDown() {
        if let delegate = delegate {
            delegate.overlay.hide()
            delegate.settings.close()
            if let item = delegate.statusItem {
                NSStatusBar.system.removeStatusItem(item)
            }
        }
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func launch() {
        delegate = AppDelegate(store: store, modifierTap: fakeTap)
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    }

    // MARK: First launch

    /// The library stores the initial shortcut in UserDefaults when the Name is first constructed (first launch in the real app).
    /// Calling APIs that unregister hotkeys (reset / setShortcut / disable) from tests crashes inside the library, so only the declared initial value is checked
    func testDefaultHotkeyIsOptionCommandZ() {
        XCTAssertEqual(
            KeyboardShortcuts.Name.showSpotlight.initialShortcut,
            KeyboardShortcuts.Shortcut(.z, modifiers: [.option, .command])
        )
    }

    func testFirstLaunchStartsDoubleTapOnLeftControl() {
        launch()
        XCTAssertEqual(fakeTap.received, [.leftControl])
    }

    func testFirstLaunchUsesSpotlightEffect() {
        launch()
        XCTAssertEqual(delegate.overlay.currentEffect, .spotlight)
        XCTAssertTrue(delegate.overlay.renderer is SpotlightRenderer)
        XCTAssertFalse(delegate.overlay.isVisible, "no overlay at launch")
    }

    func testLaunchInstallsStatusItemWithIconAndMenu() throws {
        launch()
        let item = try XCTUnwrap(delegate.statusItem)
        XCTAssertNotNil(item.button?.image, "status bar icon")
        XCTAssertEqual(item.menu?.items.count, 6)
        XCTAssertEqual(item.menu?.items.first?.title, L("menu.showSpotlight"))
    }

    func testLaunchInstallsMainMenuForShortcuts() throws {
        launch()
        let appMenu = try XCTUnwrap(NSApp.mainMenu?.items.first?.submenu)
        XCTAssertEqual(appMenu.items.map { $0.keyEquivalent }, [",", "", "q"])
    }

    // MARK: Launch with stored settings

    func testLaunchRestoresStoredSettings() {
        store.doubleTapModifier = .rightShift
        store.effect = .focusLines
        launch()
        XCTAssertEqual(fakeTap.received, [.rightShift])
        XCTAssertEqual(delegate.overlay.currentEffect, .focusLines)
    }

    // MARK: Wiring after launch

    func testSettingsWindowChangeReachesTheMonitor() {
        launch()
        let index = ModifierKey.allCases.firstIndex(of: .leftCommand)!
        delegate.settings.doubleTapPopUp.selectItem(at: index)
        delegate.settings.changeDoubleTapModifier(delegate.settings.doubleTapPopUp)
        XCTAssertEqual(fakeTap.received, [.leftControl, .leftCommand])
    }

    func testMenuTriggerShowsOverlay() {
        launch()
        delegate.triggerSpotlight()
        XCTAssertTrue(delegate.overlay.isVisible)
        XCTAssertEqual(delegate.overlay.windows.count, NSScreen.screens.count)
    }

    /// The settings window shows the monitor's status
    func testSettingsWindowShowsMonitorStatus() {
        launch()
        fakeTap.status = .active
        delegate.settings.updatePermissionStatus()
        XCTAssertEqual(delegate.settings.permissionLabel.stringValue, L("settings.permission.granted"))
        fakeTap.status = .waitingForPermission
        delegate.settings.updatePermissionStatus()
        XCTAssertEqual(delegate.settings.permissionLabel.stringValue, L("settings.permission.notGranted"))
        XCTAssertFalse(delegate.settings.permissionButton.isHidden)
    }

    func testEffectChosenInSettingsAppliesOnNextShow() {
        launch()
        let index = Effect.allCases.firstIndex(of: .flash)!
        delegate.settings.effectPopUp.selectItem(at: index)
        delegate.settings.changeEffect(delegate.settings.effectPopUp)
        delegate.triggerSpotlight()
        XCTAssertTrue(delegate.overlay.renderer is FlashRenderer)
    }
}
