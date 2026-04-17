import Foundation
import ServiceManagement

final class AppPreferences {
    static let shared = AppPreferences()
    private let ud = UserDefaults.standard

    private init() {}

    // General
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() }
                else        { try SMAppService.mainApp.unregister() }
            } catch { /* silently ignore */ }
        }
    }

    // Clipboard
    var clipboardLimit: Int {
        get { let v = ud.integer(forKey: "clip_limit"); return v > 0 ? v : 200 }
        set { ud.set(max(10, min(1000, newValue)), forKey: "clip_limit") }
    }

    // Sonos
    var sonosPollInterval: Double {
        get { let v = ud.double(forKey: "sonos_poll"); return v > 0 ? v : 5.0 }
        set { ud.set(max(1.0, min(30.0, newValue)), forKey: "sonos_poll") }
    }
    var sonosDiscoveryTimeout: Double {
        get { let v = ud.double(forKey: "sonos_disc_timeout"); return v > 0 ? v : 8.0 }
        set { ud.set(max(3.0, min(30.0, newValue)), forKey: "sonos_disc_timeout") }
    }
}
