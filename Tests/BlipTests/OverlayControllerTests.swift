import XCTest
import BlipCore
@testable import Blip

/// Builds the overlay windows for real and inspects them. syncWindowsWithScreens does not present anything; only the tests calling show do
final class OverlayControllerTests: XCTestCase {
    private let suiteName = "com.dominion525.blip.tests.overlay"
    private var defaults: UserDefaults!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeController(autoHide: TimeInterval = 1.2) -> OverlayController {
        OverlayController(store: store, dismissal: .after(autoHide))
    }

    // MARK: Window creation and configuration

    func testSyncCreatesOneWindowPerScreenWithMatchingFrames() {
        let controller = makeController()
        controller.syncWindowsWithScreens()
        let screens = NSScreen.screens
        XCTAssertEqual(controller.windows.count, screens.count)
        for (window, screen) in zip(controller.windows, screens) {
            XCTAssertEqual(window.frame, screen.frame, "covers the whole screen without being pushed below the menu bar")
            XCTAssertEqual(window.overlayView.frame.size, screen.frame.size)
        }
    }

    /// The required settings from the spec. Losing any one of them means swallowing clicks, stealing focus, or not appearing over full-screen apps
    func testWindowsAreConfiguredAsClickThroughOverlays() {
        let controller = makeController()
        controller.syncWindowsWithScreens()
        let screenSaverLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        for window in controller.windows {
            XCTAssertEqual(window.styleMask, .borderless)
            XCTAssertFalse(window.isOpaque)
            XCTAssertEqual(window.backgroundColor, .clear)
            XCTAssertFalse(window.hasShadow)
            XCTAssertTrue(window.ignoresMouseEvents, "click-through")
            XCTAssertEqual(window.level, screenSaverLevel)
            XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
            XCTAssertTrue(window.collectionBehavior.contains(.stationary))
            XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
            XCTAssertTrue(window.collectionBehavior.contains(.ignoresCycle))
            XCTAssertFalse(window.canBecomeKey, "never takes focus")
            XCTAssertFalse(window.canBecomeMain)
            XCTAssertFalse(window.isReleasedWhenClosed)
            XCTAssertTrue(window.contentView is OverlayView)
        }
    }

    func testSyncKeepsWindowsWhenScreensAreUnchanged() {
        let controller = makeController()
        controller.syncWindowsWithScreens()
        let before = controller.windows
        controller.syncWindowsWithScreens()
        XCTAssertEqual(controller.windows.count, before.count)
        for (a, b) in zip(before, controller.windows) {
            XCTAssertTrue(a === b, "not rebuilt when the configuration is unchanged")
        }
    }

    /// Simulates a display being plugged or unplugged by changing a window frame so it no longer matches
    func testSyncRebuildsWindowsWhenFramesNoLongerMatch() {
        let controller = makeController()
        controller.syncWindowsWithScreens()
        let stale = controller.windows[0]
        stale.setFrame(stale.frame.insetBy(dx: 10, dy: 10), display: false)

        controller.syncWindowsWithScreens()
        XCTAssertFalse(controller.windows.contains { $0 === stale }, "the stale window is discarded")
        XCTAssertEqual(controller.windows.map { $0.frame }, NSScreen.screens.map { $0.frame })
    }

    // MARK: Effects

    func testRendererStartsFromStoredEffect() {
        store.effect = .focusLines
        let controller = makeController()
        XCTAssertEqual(controller.currentEffect, .focusLines)
        XCTAssertTrue(controller.renderer is FocusLinesRenderer)
    }

    func testApplyEffectSettingSwapsRendererOnAllWindows() {
        let controller = makeController()
        controller.syncWindowsWithScreens()
        XCTAssertTrue(controller.renderer is SpotlightRenderer)

        store.effect = .zoom
        controller.applyEffectSetting()
        XCTAssertEqual(controller.currentEffect, .zoom)
        XCTAssertTrue(controller.renderer is ZoomRenderer)
        for window in controller.windows {
            XCTAssertTrue(window.overlayView.renderer is ZoomRenderer)
        }
    }

    func testApplyEffectSettingKeepsRendererWhenUnchanged() {
        let controller = makeController()
        let before = controller.renderer
        controller.applyEffectSetting()
        XCTAssertTrue(controller.renderer === before)
    }

    // MARK: Cursor position

    func testUpdateSpotMarksOnlyTheScreenUnderTheMouse() {
        let controller = makeController()
        controller.syncWindowsWithScreens()
        controller.updateSpot(force: true)
        let mouse = NSEvent.mouseLocation
        for window in controller.windows {
            let expected = Geometry.spotCenter(mouse: mouse, in: window.frame)
            XCTAssertEqual(window.overlayView.spot, expected)
        }
        let marked = controller.windows.filter { $0.overlayView.spot != nil }.count
        XCTAssertLessThanOrEqual(marked, 1, "at most one screen gets the hole")
    }

    // MARK: Show and hide (these present windows)

    func testShowOrdersWindowsFrontAndHideOrdersThemOut() {
        let controller = makeController()
        controller.show()
        XCTAssertTrue(controller.isVisible)
        XCTAssertFalse(controller.windows.isEmpty)
        XCTAssertTrue(controller.windows.allSatisfy { $0.isVisible })

        controller.hide()
        XCTAssertFalse(controller.isVisible)
        XCTAssertTrue(controller.windows.allSatisfy { !$0.isVisible })
    }

    func testAutoHideAfterConfiguredSeconds() {
        let controller = makeController(autoHide: 0.05)
        controller.show()
        XCTAssertTrue(controller.isVisible)

        let deadline = Date(timeIntervalSinceNow: 1)
        while controller.isVisible && Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertFalse(controller.isVisible, "hides on its own")
        XCTAssertTrue(controller.windows.allSatisfy { !$0.isVisible })
    }

    /// With no override the controller follows the setting, and it re-reads it on every show so a
    /// change made while the window is open takes effect at the next trigger
    func testShowReadsTheDismissalFromTheStore() {
        let controller = OverlayController(store: store)
        store.dismissal = .whenFound
        controller.show()
        XCTAssertEqual(controller.dismissal, .whenFound)
        store.dismissal = .after(2)
        controller.show()
        XCTAssertEqual(controller.dismissal, .after(2))
        controller.hide()
    }

    /// Waiting to be found has no deadline. The ways out are the cursor coming to rest, a click, and
    /// a key press, none of which a test can produce, so this only checks that nothing hides it
    func testWaitingToBeFoundDoesNotHideOnItsOwn() {
        let controller = OverlayController(store: store, dismissal: .whenFound)
        controller.show()
        let deadline = Date(timeIntervalSinceNow: 0.15)
        while Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertTrue(controller.isVisible, "still up with no timer to end it")
        controller.hide()
        XCTAssertFalse(controller.isVisible)
    }

    func testTriggerWhileVisibleKeepsShowing() {
        let controller = makeController(autoHide: 1.2)
        controller.trigger()
        controller.trigger()
        XCTAssertTrue(controller.isVisible, "triggering while visible keeps it visible")
        controller.hide()
    }

    // MARK: Displays coming and going

    /// Plugging a display in or out arrives as this notification. The windows are per display, so
    /// they are rebuilt; a stale set would leave the new display uncovered
    private func postScreenParametersChanged() {
        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: NSApplication.shared
        )
    }

    /// The notification also arrives for changes that leave the displays where they were, such as
    /// a resolution-independent setting. Rebuilding then would throw away windows for nothing
    func testScreenChangeKeepsTheWindowsWhenTheDisplaysDidNotMove() {
        let controller = makeController()
        controller.syncWindowsWithScreens()
        let before = controller.windows

        postScreenParametersChanged()

        XCTAssertEqual(controller.windows.count, before.count)
        XCTAssertTrue(zip(before, controller.windows).allSatisfy { $0 === $1 }, "the same windows are kept")
        XCTAssertTrue(controller.windows.allSatisfy { !$0.isVisible }, "a change while hidden does not put anything on screen")
    }

    /// A display arriving or leaving shows up as frames that no longer line up with the screens.
    /// Standing in for that by moving a window off its screen, since the test cannot add a display
    func testScreenChangeRebuildsTheWindowsWhenTheFramesNoLongerMatch() throws {
        let controller = makeController()
        controller.syncWindowsWithScreens()
        let before = controller.windows
        let stale = try XCTUnwrap(before.first)
        stale.setFrame(stale.frame.insetBy(dx: 10, dy: 10), display: false)

        postScreenParametersChanged()

        XCTAssertEqual(controller.windows.count, NSScreen.screens.count)
        XCTAssertFalse(controller.windows.contains { $0 === stale }, "the window that no longer fits is replaced")
        for (window, screen) in zip(controller.windows, NSScreen.screens) {
            XCTAssertEqual(window.frame, screen.frame, "the rebuilt windows cover their screens again")
        }
    }

    func testScreenChangeWhileVisibleKeepsTheEffectOnScreen() {
        let controller = makeController(autoHide: 5)
        controller.show()
        XCTAssertTrue(controller.isVisible)

        postScreenParametersChanged()

        XCTAssertTrue(controller.isVisible)
        XCTAssertEqual(controller.windows.count, NSScreen.screens.count)
        XCTAssertTrue(controller.windows.allSatisfy { $0.isVisible }, "the rebuilt windows are presented, not left behind")
        controller.hide()
    }
}
