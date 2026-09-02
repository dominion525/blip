// The settings window. There is no save button; every change is written to UserDefaults immediately.

import AppKit
import BlipCore
import KeyboardShortcuts
import ServiceManagement

final class SettingsWindowController: NSWindowController {
    /// Called when the Control double-tap is enabled or disabled
    var onControlDoubleTapChanged: ((Bool) -> Void)?

    private let controlDoubleTapCheckbox = NSButton(checkboxWithTitle: "Control double-tap", target: nil, action: nil)
    private let effectPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Blip Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        controlDoubleTapCheckbox.target = self
        controlDoubleTapCheckbox.action = #selector(toggleControlDoubleTap(_:))

        effectPopUp.addItems(withTitles: Effect.allCases.map { $0.displayName })
        effectPopUp.target = self
        effectPopUp.action = #selector(changeEffect(_:))

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin(_:))

        let recorder = KeyboardShortcuts.RecorderCocoa(for: .showSpotlight)

        // Labels in the left column, controls in the right. Section headers are bold labels
        let grid = NSGridView(views: [
            [sectionLabel("Hotkey"), NSGridCell.emptyContentView],
            [fieldLabel("Show spotlight:"), recorder],
            [NSGridCell.emptyContentView, controlDoubleTapCheckbox],
            [sectionLabel("Effect"), NSGridCell.emptyContentView],
            [fieldLabel("Effect:"), effectPopUp],
            [sectionLabel("General"), NSGridCell.emptyContentView],
            [NSGridCell.emptyContentView, launchAtLoginCheckbox],
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        grid.rowAlignment = .firstBaseline
        for index in [0, 3, 5] {
            grid.row(at: index).topPadding = index == 0 ? 0 : 12
        }
        grid.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
        ])
        window.contentView = content
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        controlDoubleTapCheckbox.state = Settings.controlDoubleTapEnabled ? .on : .off
        effectPopUp.selectItem(at: Effect.allCases.firstIndex(of: Settings.effect) ?? 0)
        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Actions

    @objc private func toggleControlDoubleTap(_ sender: NSButton) {
        let enabled = sender.state == .on
        Settings.controlDoubleTapEnabled = enabled
        onControlDoubleTapChanged?(enabled)
    }

    @objc private func changeEffect(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard Effect.allCases.indices.contains(index) else { return }
        Settings.effect = Effect.allCases[index]
        NSLog("Blip: effect set to %@", Settings.effect.rawValue)
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

    // MARK: Labels

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        return label
    }

    private func fieldLabel(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }
}
