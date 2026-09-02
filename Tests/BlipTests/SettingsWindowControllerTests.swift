import XCTest
import BlipCore
@testable import Blip

/// Builds the settings window and inspects its controls without presenting it (show is not called)
final class SettingsWindowControllerTests: XCTestCase {
    private let suiteName = "local.blip.tests.settingswindow"
    private var defaults: UserDefaults!
    private var store: SettingsStore!
    private var controller: SettingsWindowController!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SettingsStore(defaults: defaults)
        controller = SettingsWindowController(store: store)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: Window

    func testWindowIsTitledClosableAndReusable() throws {
        let window = try XCTUnwrap(controller.window)
        XCTAssertEqual(window.title, L("settings.title"))
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertFalse(window.styleMask.contains(.resizable))
        XCTAssertFalse(window.isReleasedWhenClosed, "reopens after closing")
        XCTAssertTrue(window.delegate === controller)
    }

    func testWindowSizeFitsContent() throws {
        let window = try XCTUnwrap(controller.window)
        let content = try XCTUnwrap(window.contentView)
        XCTAssertGreaterThan(content.frame.width, 300)
        XCTAssertGreaterThan(content.frame.height, 200)
        XCTAssertEqual(content.frame.size, content.fittingSize)
    }

    // MARK: Choices

    func testEffectPopUpListsEveryEffectInOrder() {
        XCTAssertEqual(controller.effectPopUp.itemTitles, Effect.allCases.map { $0.localizedName })
    }

    func testDoubleTapPopUpListsEveryModifierInOrder() {
        XCTAssertEqual(controller.doubleTapPopUp.itemTitles, ModifierKey.allCases.map { $0.localizedName })
    }

    func testControlsAreWiredToTheController() {
        XCTAssertTrue(controller.effectPopUp.target === controller)
        XCTAssertEqual(controller.effectPopUp.action, #selector(SettingsWindowController.changeEffect(_:)))
        XCTAssertTrue(controller.doubleTapPopUp.target === controller)
        XCTAssertEqual(controller.doubleTapPopUp.action, #selector(SettingsWindowController.changeDoubleTapModifier(_:)))
        XCTAssertTrue(controller.launchAtLoginCheckbox.target === controller)
        XCTAssertTrue(controller.permissionButton.target === controller)
    }

    // MARK: Loading stored values

    func testLoadValuesSelectsStoredChoices() {
        store.effect = .flash
        store.doubleTapModifier = .rightOption
        controller.loadValues()
        XCTAssertEqual(controller.effectPopUp.indexOfSelectedItem, Effect.allCases.firstIndex(of: .flash))
        XCTAssertEqual(controller.doubleTapPopUp.indexOfSelectedItem, ModifierKey.allCases.firstIndex(of: .rightOption))
    }

    func testLoadValuesSelectsDefaultsWhenNothingIsStored() {
        controller.loadValues()
        XCTAssertEqual(controller.effectPopUp.indexOfSelectedItem, Effect.allCases.firstIndex(of: Effect.default))
        XCTAssertEqual(controller.doubleTapPopUp.indexOfSelectedItem, ModifierKey.allCases.firstIndex(of: ModifierKey.default))
    }

    // MARK: Applying changes

    func testChangingEffectPersistsImmediately() {
        let index = Effect.allCases.firstIndex(of: .focusLines)!
        controller.effectPopUp.selectItem(at: index)
        controller.changeEffect(controller.effectPopUp)
        XCTAssertEqual(store.effect, .focusLines)
    }

    func testChangingDoubleTapModifierPersistsAndNotifies() {
        var notified: [ModifierKey] = []
        controller.onDoubleTapModifierChanged = { notified.append($0) }

        let index = ModifierKey.allCases.firstIndex(of: .leftCommand)!
        controller.doubleTapPopUp.selectItem(at: index)
        controller.changeDoubleTapModifier(controller.doubleTapPopUp)

        XCTAssertEqual(store.doubleTapModifier, .leftCommand)
        XCTAssertEqual(notified, [.leftCommand])
    }

    func testSelectingOffDisablesDoubleTap() {
        var notified: [ModifierKey] = []
        controller.onDoubleTapModifierChanged = { notified.append($0) }
        controller.doubleTapPopUp.selectItem(at: 0)
        controller.changeDoubleTapModifier(controller.doubleTapPopUp)
        XCTAssertEqual(store.doubleTapModifier, .off)
        XCTAssertEqual(notified, [.off])
    }

    // MARK: Permission display

    func testPermissionStatusMatchesSystemState() {
        controller.updatePermissionStatus()
        if ModifierTapMonitor.hasPermission {
            XCTAssertEqual(controller.permissionLabel.stringValue, L("settings.permission.granted"))
            XCTAssertTrue(controller.permissionButton.isHidden, "no button once granted")
        } else {
            XCTAssertEqual(controller.permissionLabel.stringValue, L("settings.permission.notGranted"))
            XCTAssertFalse(controller.permissionButton.isHidden, "offers to open System Settings while not granted")
        }
    }
}
