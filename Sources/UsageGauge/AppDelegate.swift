import AppKit
import Carbon
import Combine
import SwiftUI
import UsageGaugeCore
import UsageGaugeUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let refreshInterval: TimeInterval = 120
    private static let tickInterval: TimeInterval = 15
    private static let tintChangeThreshold = 0.03
    private static let adaptiveTintTitle = "배경에 맞춰 유리 진하기 조절"

    private let store = UsageStore()
    private let panelState = PanelState()
    private var panel: GaugePanel!
    private var statusItem: StatusItemController!
    private var hotKey: HotKey?
    private var timers: [Timer] = []
    private var storeObservation: AnyCancellable?
    private var opacitySlider: NSSlider?
    private var adaptiveTintItem: NSMenuItem?
    private var styleItems: [NSMenuItem] = []
    private var backdropSampler: BackdropSampler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = buildMenu()
        let hostingView = FirstMouseHostingView(rootView: PanelRoot(store: store, state: panelState,
                                                               onOpacity: { [weak self] in self?.setOpacity($0) },
                                                               onResize: { [weak self] in self?.panel.fitContent() },
                                                               onClose: { [weak self] in self?.togglePanel() }))
        hostingView.menu = menu
        panel = GaugePanel(contentView: hostingView)
        setOpacity(Preferences.panelOpacity)
        backdropSampler = BackdropSampler(
            window: panel,
            onLuminance: { [weak self] in self?.applyBackdrop(luminance: $0) },
            onUnavailable: { [weak self] in self?.adaptiveTintUnavailable($0) })
        statusItem = StatusItemController(menu: menu) { [weak self] in self?.togglePanel() }
        hotKey = HotKey(id: 1, keyCode: kVK_ANSI_U, modifiers: cmdKey | optionKey) { [weak self] in self?.togglePanel() }

        storeObservation = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.syncChrome() }
        }
        if Preferences.isPanelVisible { panel.orderFrontRegardless() }
        panelState.isShown = panel.isVisible
        syncAdaptiveTint()
        syncChrome()

        store.refresh()
        timers = [
            Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.store.refresh() }
            },
            Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.store.tick()
                    self?.panel.rememberPosition()
                }
            },
        ]
        // Numbers go stale while the Mac sleeps; fetch as soon as it wakes.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil,
                                                          queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.store.tick()
                self?.store.refreshIfStale()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        panel.rememberPosition()
    }

    /// Opening the app again (Spotlight, Finder, `open -a`) toggles the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        togglePanel()
        return false
    }

    private func syncChrome() {
        statusItem.update(providers: store.providers)
        panel.fitContent()
    }

    @objc private func togglePanel() {
        let show = !panel.isVisible
        if show {
            panel.orderFrontRegardless()
            store.refreshIfStale()
        } else {
            panel.orderOut(nil)
        }
        Preferences.isPanelVisible = show
        panelState.isShown = show
        syncAdaptiveTint()
    }

    @objc private func toggleAdaptiveTint() {
        Preferences.isAdaptiveTint.toggle()
        syncAdaptiveTint()
    }

    /// Samples the backdrop only while the panel is shown and the option is on.
    private func syncAdaptiveTint() {
        adaptiveTintItem?.state = Preferences.isAdaptiveTint ? .on : .off
        adaptiveTintItem?.title = Self.adaptiveTintTitle
        if Preferences.isAdaptiveTint && panel.isVisible {
            backdropSampler?.start()
        } else {
            backdropSampler?.stop()
            if !Preferences.isAdaptiveTint { panelState.tintOpacity = BackdropTone.fallbackTint }
        }
    }

    private func applyBackdrop(luminance: Double) {
        let tint = BackdropTone.tintOpacity(luminance: luminance)
        // Small changes are noise from moving content; only follow real shifts.
        guard abs(tint - panelState.tintOpacity) > Self.tintChangeThreshold else { return }
        panelState.tintOpacity = tint
    }

    private func adaptiveTintUnavailable(_ message: String) {
        panelState.tintOpacity = BackdropTone.fallbackTint
        adaptiveTintItem?.toolTip = message
    }

    @objc private func chooseStyle(_ sender: NSMenuItem) {
        guard let style = sender.representedObject as? String, let chosen = PanelStyle(rawValue: style) else { return }
        Preferences.panelStyle = chosen
        panelState.style = chosen
        syncStyleItems()
    }

    private func syncStyleItems() {
        styleItems.forEach { $0.state = $0.representedObject as? String == Preferences.panelStyle.rawValue ? .on : .off }
    }

    @objc private func refreshNow() {
        store.refresh()
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        setOpacity(sender.doubleValue)
    }

    /// Single place the opacity changes, so the panel, both sliders and the saved value agree.
    private func setOpacity(_ value: Double) {
        Preferences.panelOpacity = value
        let opacity = Preferences.panelOpacity
        panel?.alphaValue = opacity
        opacitySlider?.doubleValue = opacity
        if panelState.opacity != opacity { panelState.opacity = opacity }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("게이지 켜기/끄기 (⌥⌘U)", #selector(togglePanel)))
        menu.addItem(item("지금 새로고침", #selector(refreshNow)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem.sectionHeader(title: "스타일"))
        styleItems = PanelStyle.allCases.map { style in
            let entry = item(style.title, #selector(chooseStyle(_:)))
            entry.representedObject = style.rawValue
            return entry
        }
        styleItems.forEach(menu.addItem)
        syncStyleItems()
        menu.addItem(.separator())
        menu.addItem(NSMenuItem.sectionHeader(title: "게이지 투명도"))
        menu.addItem(opacitySliderItem())
        let adaptive = item(Self.adaptiveTintTitle, #selector(toggleAdaptiveTint))
        adaptiveTintItem = adaptive
        menu.addItem(adaptive)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    /// Live slider: the panel follows while dragging and the value is remembered.
    private func opacitySliderItem() -> NSMenuItem {
        let slider = NSSlider(value: Preferences.panelOpacity,
                              minValue: Preferences.opacityRange.lowerBound,
                              maxValue: Preferences.opacityRange.upperBound,
                              target: self, action: #selector(opacityChanged(_:)))
        slider.isContinuous = true
        opacitySlider = slider
        slider.frame = NSRect(x: 20, y: 4, width: 180, height: 22)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        container.addSubview(slider)
        let entry = NSMenuItem()
        entry.view = container
        return entry
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        return entry
    }
}

/// The panel never becomes key, so the first click must already reach the controls (and start drags).
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Panel state the view follows: whether it is on screen (the animation stops while hidden),
/// its opacity and style, and how dark the glass is for the current backdrop.
private final class PanelState: ObservableObject {
    @Published var isShown = false
    @Published var opacity = Preferences.panelOpacity
    @Published var style = Preferences.panelStyle
    @Published var tintOpacity = BackdropTone.fallbackTint
}

private struct PanelRoot: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var state: PanelState
    let onOpacity: (Double) -> Void
    let onResize: () -> Void
    let onClose: () -> Void

    var body: some View {
        GaugeView(providers: store.providers, status: store.statusText, now: store.now, onClose: onClose,
                  opacity: Binding(get: { state.opacity }, set: onOpacity),
                  opacityRange: Preferences.opacityRange, style: state.style,
                  frozenAt: state.isShown ? nil : 0)
            .modifier(PanelSurface(style: state.style, tintOpacity: state.tintOpacity))
            .animation(.easeInOut(duration: 0.8), value: state.tintOpacity)
            // The panel follows the content when rows appear, e.g. the opacity slider.
            .background(GeometryReader { geo in
                Color.clear.onChange(of: geo.size) { onResize() }
            })
    }
}
