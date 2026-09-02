// The settings window. There is no save button; every change is written to UserDefaults immediately.

import AppKit
import BlipCore
import KeyboardShortcuts
import ServiceManagement

final class SettingsWindowController: NSWindowController {
    /// Called when the double-tap modifier changes
    var onDoubleTapModifierChanged: ((ModifierKey) -> Void)?

    private let doubleTapPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionButton = NSButton(title: "Open System Settings", target: nil, action: nil)
    private var permissionTimer: Timer?
    private let effectPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Blip Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        doubleTapPopUp.addItems(withTitles: ModifierKey.allCases.map { $0.displayName })
        doubleTapPopUp.target = self
        doubleTapPopUp.action = #selector(changeDoubleTapModifier(_:))

        permissionLabel.textColor = .secondaryLabelColor
        permissionLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        permissionButton.target = self
        permissionButton.action = #selector(openSystemSettings)
        permissionButton.controlSize = .small
        permissionButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let permissionRow = NSStackView(views: [permissionLabel, permissionButton])
        permissionRow.orientation = .horizontal
        permissionRow.spacing = 8

        effectPopUp.addItems(withTitles: Effect.allCases.map { $0.displayName })
        effectPopUp.target = self
        effectPopUp.action = #selector(changeEffect(_:))

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin(_:))

        let recorder = KeyboardShortcuts.RecorderCocoa(for: .showSpotlight) { shortcut in
            NSLog("Blip: hotkey recorded %@", shortcut.map { String(describing: $0) } ?? "(cleared)")
        }

        // Labels in the left column, controls in the right. Section headers are bold labels
        let grid = NSGridView(views: [
            [sectionLabel("Hotkey"), NSGridCell.emptyContentView],
            [fieldLabel("Show spotlight:"), recorder],
            [fieldLabel("Double-tap modifier:"), doubleTapPopUp],
            [NSGridCell.emptyContentView, permissionRow],
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
        // Section headers span both columns, left-aligned. Sections after the first get extra spacing above
        for index in [0, 4, 6] {
            grid.mergeCells(inHorizontalRange: NSRange(location: 0, length: 2), verticalRange: NSRange(location: index, length: 1))
            grid.cell(atColumnIndex: 0, rowIndex: index).xPlacement = .leading
            grid.row(at: index).topPadding = index == 0 ? 0 : 16
        }
        grid.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
        ])
        window.contentView = content
        // Size the window to its content. A fixed size stretches the grid and piles the slack into one gap
        content.layoutSubtreeIfNeeded()
        window.setContentSize(content.fittingSize)
        window.center()
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        doubleTapPopUp.selectItem(at: ModifierKey.allCases.firstIndex(of: Settings.doubleTapModifier) ?? 0)
        effectPopUp.selectItem(at: Effect.allCases.firstIndex(of: Settings.effect) ?? 0)
        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        updatePermissionStatus()
        // Permission changes in System Settings, so re-check every second while shown
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePermissionStatus()
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func updatePermissionStatus() {
        let granted = ModifierTapMonitor.hasPermission
        permissionLabel.stringValue = granted
            ? "Input Monitoring: granted"
            : "Input Monitoring: not granted (required for double-tap)"
        permissionButton.isHidden = granted
    }

    // MARK: Actions

    @objc private func changeDoubleTapModifier(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard ModifierKey.allCases.indices.contains(index) else { return }
        Settings.doubleTapModifier = ModifierKey.allCases[index]
        onDoubleTapModifierChanged?(Settings.doubleTapModifier)
    }

    @objc private func changeEffect(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard Effect.allCases.indices.contains(index) else { return }
        Settings.effect = Effect.allCases[index]
        NSLog("Blip: effect set to %@", Settings.effect.rawValue)
    }

    @objc private func openSystemSettings() {
        ModifierTapMonitor.openSystemSettings()
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

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }
}
