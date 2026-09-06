import XCTest
@testable import Blip

final class AppDelegateMenuTests: XCTestCase {
    func testStatusMenuHasTheExpectedItemsInOrder() {
        let menu = AppDelegate(store: SettingsStore(defaults: UserDefaults(suiteName: "com.dominion525.blip.tests.menu")!)).makeStatusMenu()
        XCTAssertEqual(menu.items.count, 8)
        XCTAssertEqual(menu.items[0].title, L("menu.showSpotlight"))
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertEqual(menu.items[2].title, L("menu.settings"))
        XCTAssertEqual(menu.items[3].title, L("menu.about"))
        XCTAssertEqual(menu.items[4].title, L("menu.checkForUpdates"))
        XCTAssertTrue(menu.items[5].isSeparatorItem)
        XCTAssertEqual(menu.items[6].title, L("menu.restart"))
        XCTAssertEqual(menu.items[7].title, L("menu.quit"))
    }

    func testStatusMenuShortcuts() {
        let menu = AppDelegate(store: SettingsStore(defaults: UserDefaults(suiteName: "com.dominion525.blip.tests.menu")!)).makeStatusMenu()
        XCTAssertEqual(menu.items[2].keyEquivalent, ",")
        XCTAssertEqual(menu.items[2].keyEquivalentModifierMask, .command)
        XCTAssertEqual(menu.items[4].keyEquivalent, "")
        XCTAssertEqual(menu.items[4].action, #selector(AppDelegate.checkForUpdates))
        XCTAssertEqual(menu.items[6].keyEquivalent, "")
        XCTAssertEqual(menu.items[6].action, #selector(AppDelegate.restart))
        XCTAssertEqual(menu.items[7].keyEquivalent, "q")
        XCTAssertEqual(menu.items[7].action, #selector(NSApplication.terminate(_:)))
    }

    func testStatusMenuItemsTargetTheDelegate() {
        let delegate = AppDelegate(store: SettingsStore(defaults: UserDefaults(suiteName: "com.dominion525.blip.tests.menu")!))
        let menu = delegate.makeStatusMenu()
        for index in [0, 2, 3, 4, 6] {
            XCTAssertTrue(menu.items[index].target === delegate, menu.items[index].title)
            XCTAssertNotNil(menu.items[index].action)
        }
    }

    /// The invisible main menu that makes ⌘, and ⌘Q work on the settings window
    func testMainMenuProvidesSettingsAndQuitShortcuts() throws {
        let menu = AppDelegate(store: SettingsStore(defaults: UserDefaults(suiteName: "com.dominion525.blip.tests.menu")!)).makeMainMenu()
        XCTAssertEqual(menu.items.count, 1)
        let appMenu = try XCTUnwrap(menu.items[0].submenu)
        XCTAssertEqual(appMenu.items.count, 3)
        XCTAssertEqual(appMenu.items[0].title, L("menu.settings"))
        XCTAssertEqual(appMenu.items[0].keyEquivalent, ",")
        XCTAssertTrue(appMenu.items[1].isSeparatorItem)
        XCTAssertEqual(appMenu.items[2].title, L("menu.quit"))
        XCTAssertEqual(appMenu.items[2].keyEquivalent, "q")
    }
}
