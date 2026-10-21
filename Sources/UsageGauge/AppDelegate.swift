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
    private var scaleSlider: NSSlider?
    private var adaptiveTintItem: NSMenuItem?
    private var styleItems: [NSMenuItem] = []
    private var layoutItems: [NSMenuItem] = []
    private var menuBarBarsItem: NSMenuItem?
    private var backdropSampler: BackdropSampler?
    private let loginItem = LoginItem()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = buildMenu()
        let hostingView = FirstMouseHostingView(rootView: PanelRoot(store: store, state: panelState,
                                                               onOpacity: { [weak self] in self?.setOpacity($0) },
                                                               onScale: { [weak self] in self?.setScale($0) },
                                                               onResize: { [weak self] in self?.panel.fitContent() },
                                                               onLayout: { [weak self] in self?.applyLayout($0) },
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
        loginItem.registerOnFirstLaunch()

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
        statusItem.update(providers: store.providers, showsBars: Preferences.showsMenuBarBars)
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

    @objc private func chooseLayout(_ sender: NSMenuItem) {
        guard let layout = sender.representedObject as? String, let chosen = PanelLayout(rawValue: layout) else { return }
        applyLayout(chosen)
    }

    /// Single place the graph form changes, for the menu and the panel's own picker.
    private func applyLayout(_ layout: PanelLayout) {
        Preferences.panelLayout = layout
        panelState.layout = layout
        syncLayoutItems()
    }

    private func syncLayoutItems() {
        layoutItems.forEach { $0.state = $0.representedObject as? String == Preferences.panelLayout.rawValue ? .on : .off }
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

    @objc private func toggleMenuBarBars() {
        Preferences.showsMenuBarBars.toggle()
        menuBarBarsItem?.state = Preferences.showsMenuBarBars ? .on : .off
        syncChrome()
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

    @objc private func scaleChanged(_ sender: NSSlider) {
        setScale(sender.doubleValue)
    }

    /// Single place the size changes; the panel's window follows its scaled content.
    private func setScale(_ value: Double) {
        Preferences.panelScale = value
        let scale = Preferences.panelScale
        scaleSlider?.doubleValue = scale
        if panelState.scale != scale { panelState.scale = scale }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("게이지 켜기/끄기 (⌥⌘U)", #selector(togglePanel)))
        menu.addItem(item("지금 새로고침", #selector(refreshNow)))
        menu.addItem(.separator())
        let layoutMenu = NSMenu()
        layoutItems = PanelLayout.allCases.map { layout in
            let entry = item(layout.title, #selector(chooseLayout(_:)))
            entry.representedObject = layout.rawValue
            return entry
        }
        layoutItems.forEach(layoutMenu.addItem)
        syncLayoutItems()
        let layoutEntry = NSMenuItem(title: "그래프", action: nil, keyEquivalent: "")
        layoutEntry.submenu = layoutMenu
        menu.addItem(layoutEntry)
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
        let opacity = liveSliderItem(value: Preferences.panelOpacity, range: Preferences.opacityRange,
                                     action: #selector(opacityChanged(_:)))
        opacitySlider = opacity.slider
        menu.addItem(opacity.item)
        let adaptive = item(Self.adaptiveTintTitle, #selector(toggleAdaptiveTint))
        adaptiveTintItem = adaptive
        menu.addItem(adaptive)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem.sectionHeader(title: "게이지 크기"))
        let size = liveSliderItem(value: Preferences.panelScale, range: Preferences.scaleRange,
                                  action: #selector(scaleChanged(_:)))
        scaleSlider = size.slider
        menu.addItem(size.item)
        menu.addItem(.separator())
        let bars = item("메뉴바에 막대 표시", #selector(toggleMenuBarBars))
        bars.state = Preferences.showsMenuBarBars ? .on : .off
        menuBarBarsItem = bars
        menu.addItem(bars)
        menu.addItem(.separator())
        menu.addItem(loginItem.item)
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    /// Live slider: the panel follows while dragging and the value is remembered.
    private func liveSliderItem(value: Double, range: ClosedRange<Double>,
                                action: Selector) -> (item: NSMenuItem, slider: NSSlider) {
        let slider = NSSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound,
                              target: self, action: action)
        slider.isContinuous = true
        slider.frame = NSRect(x: 20, y: 4, width: 180, height: 22)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        container.addSubview(slider)
        let entry = NSMenuItem()
        entry.view = container
        return (entry, slider)
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
/// its opacity, size, style and layout, and how dark the glass is for the current backdrop.
private final class PanelState: ObservableObject {
    @Published var isShown = false
    @Published var opacity = Preferences.panelOpacity
    @Published var scale = Preferences.panelScale
    @Published var style = Preferences.panelStyle
    @Published var layout = Preferences.panelLayout
    @Published var tintOpacity = BackdropTone.fallbackTint
}

private struct PanelRoot: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var state: PanelState
    let onOpacity: (Double) -> Void
    let onScale: (Double) -> Void
    let onResize: () -> Void
    let onLayout: (PanelLayout) -> Void
    let onClose: () -> Void

    var body: some View {
        GaugeView(providers: store.providers, status: store.statusText, now: store.now, onClose: onClose,
                  opacity: Binding(get: { state.opacity }, set: onOpacity),
                  opacityRange: Preferences.opacityRange,
                  scale: Binding(get: { state.scale }, set: onScale), scaleRange: Preferences.scaleRange,
                  style: state.style, layout: state.layout, history: store.history,
                  frozenAt: state.isShown ? nil : 0, onLayout: onLayout)
            .modifier(PanelSurface(style: state.style, tintOpacity: state.tintOpacity))
            .panelScale(state.scale)
            .animation(.easeInOut(duration: 0.8), value: state.tintOpacity)
            // The panel follows the scaled content when rows appear (e.g. the control bars) or the size changes.
            .background(GeometryReader { geo in
                Color.clear.onChange(of: geo.size) { onResize() }
            })
    }
}
