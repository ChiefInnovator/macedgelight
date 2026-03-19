import Foundation
import ServiceManagement

class LoginItemManager {
    static let shared = LoginItemManager()

    private init() {}

    /// Register or unregister the app as a login item using SMAppService (macOS 13+)
    func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        } else {
            // Fallback for macOS 12 and earlier
            SMLoginItemSetEnabled("com.macedgelight.app" as CFString, enabled)
        }
    }

    /// Check current registration status
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    /// Sync the setting with the actual system state on launch
    func syncWithSystemState() {
        let settings = AppSettings.shared
        let systemEnabled = isEnabled
        if settings.launchAtLogin != systemEnabled {
            settings.launchAtLogin = systemEnabled
        }
    }
}
