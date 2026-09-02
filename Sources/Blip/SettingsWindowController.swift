// The settings window. There is no save button; every change is written to UserDefaults immediately.

import AppKit
import BlipCore
import KeyboardShortcuts
import ServiceManagement

final class SettingsWindowController: NSWindowController {
    /// Called when the double-tap modifier changes
    var onDoubleTapModifierChanged: ((ModifierKey) -> Void)?
    /// Status of the double-tap monitor, supplied by AppDelegate. When off, only the permission state is shown
    var monitorStatus: () -> ModifierTapMonitor.Status = { .off }

    let doubleTapPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    let permissionLabel = NSTextField(labelWithString: "")
    let permissionButton = NSButton(title: L("settings.permission.openSystemSettings"), target: nil, action: nil)
    private var permissionTimer: Timer?
    let effectPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    let launchAtLoginCheckbox = NSButton(checkboxWithTitle: L("settings.launchAtLogin"), target: nil, action: nil)
    private let store: SettingsStore

    init(store: SettingsStore = Settings.store) {
        self.store = store
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L("settings.title")
        window.isReleasedWhenClosed = false
        super.init(window: window)

        doubleTapPopUp.addItems(withTitles: ModifierKey.allCases.map { $0.localizedName })
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

        effectPopUp.addItems(withTitles: Effect.allCases.map { $0.localizedName })
        effectPopUp.target = self
        effectPopUp.action = #selector(changeEffect(_:))

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin(_:))

        let recorder = KeyboardShortcuts.RecorderCocoa(for: .showSpotlight) { shortcut in
            NSLog("Blip: hotkey recorded %@", shortcut.map { String(describing: $0) } ?? "(cleared)")
        }

        // Labels in the left column, controls in the right. Section headers are bold labels
        let grid = NSGridView(views: [
            [sectionLabel(L("settings.section.hotkey")), NSGridCell.emptyContentView],
            [fieldLabel(L("settings.hotkey.showSpotlight")), recorder],
            [fieldLabel(L("settings.hotkey.doubleTapModifier")), doubleTapPopUp],
            [NSGridCell.emptyContentView, permissionRow],
            [sectionLabel(L("settings.section.effect")), NSGridCell.emptyContentView],
            [fieldLabel(L("settings.effect")), effectPopUp],
            [sectionLabel(L("settings.section.general")), NSGridCell.emptyContentView],
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
        loadValues()
        // Permission changes in System Settings, so re-check every second while shown
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePermissionStatus()
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Loads stored values and OS state into the controls. Called every time the window opens
    func loadValues() {
        doubleTapPopUp.selectItem(at: ModifierKey.allCases.firstIndex(of: store.doubleTapModifier) ?? 0)
        effectPopUp.selectItem(at: Effect.allCases.firstIndex(of: store.effect) ?? 0)
        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        updatePermissionStatus()
    }

    func updatePermissionStatus() {
        // "Granted" only while the permission exists and the tap is alive. Revoking it puts the monitor back to waiting, which shows here too
        let granted: Bool
        switch monitorStatus() {
        case .active: granted = true
        case .waitingForPermission: granted = false
        case .off: granted = ModifierTapMonitor.hasPermission
        }
        permissionLabel.stringValue = granted
            ? L("settings.permission.granted")
            : L("settings.permission.notGranted")
        permissionButton.isHidden = granted
    }

    // MARK: Actions

    @objc func changeDoubleTapModifier(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard ModifierKey.allCases.indices.contains(index) else { return }
        store.doubleTapModifier = ModifierKey.allCases[index]
        onDoubleTapModifierChanged?(store.doubleTapModifier)
    }

    @objc func changeEffect(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard Effect.allCases.indices.contains(index) else { return }
        store.effect = Effect.allCases[index]
        NSLog("Blip: effect set to %@", store.effect.rawValue)
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
