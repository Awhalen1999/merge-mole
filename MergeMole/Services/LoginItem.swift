import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService` for the "launch at login" toggle. Errors are
/// swallowed on purpose — in an unsigned dev build registration can fail, and a
/// failed toggle should never crash or block Settings.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Best-effort; status reflects reality on next read.
        }
    }
}
