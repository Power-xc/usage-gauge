import AppKit
import ServiceManagement

/// "로그인할 때 켜기" menu item backed by this app's own login item (`SMAppService.mainApp`).
@MainActor
final class LoginItem: NSObject, NSMenuItemValidation {
    private static let title = "로그인할 때 켜기"
    private let service = SMAppService.mainApp
    let item: NSMenuItem
    /// Set when registering failed or needs approval; the next click opens System Settings instead.
    private var needsSettings = false

    override init() {
        item = NSMenuItem(title: Self.title, action: #selector(toggle), keyEquivalent: "")
        super.init()
        item.target = self
    }

    /// Registers once on the very first launch so the gauge starts at login by default.
    func registerOnFirstLaunch() {
        guard !Preferences.hasAskedLoginItem else { return }
        Preferences.hasAskedLoginItem = true
        setRegistered(true)
    }

    /// Runs each time the menu opens, so the check mark follows what System Settings says.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem === item { menuItem.state = service.status == .enabled ? .on : .off }
        return true
    }

    @objc private func toggle() {
        if needsSettings || service.status == .requiresApproval {
            needsSettings = false
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        setRegistered(service.status != .enabled)
    }

    private func setRegistered(_ isOn: Bool) {
        do {
            if isOn { try service.register() } else { try service.unregister() }
            needsSettings = service.status == .requiresApproval
        } catch {
            NSLog("UsageGauge: login item \(isOn ? "register" : "unregister") failed: \(error)")
            needsSettings = isOn
        }
    }
}
