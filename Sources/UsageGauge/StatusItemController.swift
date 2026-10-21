import AppKit
import SwiftUI
import UsageGaugeCore
import UsageGaugeUI

/// Menu bar item that renders `MenuBarView`. Left-click toggles the panel, right-click opens the menu.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let hostingView = PassthroughHostingView(rootView: MenuBarView(providers: []))
    private let menu: NSMenu
    private let onToggle: () -> Void

    init(menu: NSMenu, onToggle: @escaping () -> Void) {
        self.menu = menu
        self.onToggle = onToggle
        super.init()
        item.autosaveName = "usage-gauge-menubar"
        guard let button = item.button else { return }
        button.addSubview(hostingView)
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "남은 사용량 · 클릭해서 게이지 켜기/끄기 (⌥⌘U)"
    }

    func update(providers: [ProviderUsage]) {
        hostingView.rootView = MenuBarView(providers: providers)
        let width = hostingView.fittingSize.width
        item.length = width
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: item.button?.bounds.height ?? NSStatusBar.system.thickness)
    }

    @objc private func clicked() {
        guard NSApp.currentEvent?.type == .rightMouseUp, let button = item.button else {
            onToggle()
            return
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }
}

/// Lets clicks fall through to the status bar button underneath.
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
