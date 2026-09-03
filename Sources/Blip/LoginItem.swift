// Launch at login. A thin wrapper around SMAppService (macOS 13) that tests replace with a fake.

import ServiceManagement

protocol LoginItemService: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    /// Opens Login Items in System Settings (offered while approval is pending)
    func openSystemSettings()
}

final class MainAppLoginItem: LoginItemService {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
