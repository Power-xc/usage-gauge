import AppKit
import ScreenCaptureKit
import UsageGaugeCore

/// Reads how bright the screen is behind the panel, so the glass can deepen over light content
/// and clear over dark. It captures a tiny, downscaled image of the panel's area (the panel itself
/// excluded) every few seconds while the panel is shown; nothing is kept. macOS asks for
/// screen-recording permission the first time; without it the glass keeps a fixed tint.
@MainActor
final class BackdropSampler {
    private static let interval: TimeInterval = 2
    private static let captureSide = 24

    private weak var window: NSWindow?
    private let onLuminance: (Double) -> Void
    private let onUnavailable: (String) -> Void
    private var timer: Timer?
    private var moveObserver: NSObjectProtocol?
    private var isCapturing = false

    init(window: NSWindow, onLuminance: @escaping (Double) -> Void, onUnavailable: @escaping (String) -> Void) {
        self.window = window
        self.onLuminance = onLuminance
        self.onUnavailable = onUnavailable
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.sample() }
        }
        moveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: window,
                                                              queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.sample() }
        }
        Task { await sample() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let moveObserver { NotificationCenter.default.removeObserver(moveObserver) }
        moveObserver = nil
    }

    private func sample() async {
        guard !isCapturing, let window, window.isVisible, let screen = window.screen else { return }
        isCapturing = true
        defer { isCapturing = false }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return }
            let ownWindows = content.windows.filter { $0.windowID == CGWindowID(window.windowNumber) }
            let configuration = SCStreamConfiguration()
            // Display coordinates run from the top-left in points; AppKit's from the bottom-left.
            configuration.sourceRect = CGRect(x: window.frame.minX - screen.frame.minX,
                                              y: screen.frame.maxY - window.frame.maxY,
                                              width: window.frame.width, height: window.frame.height)
            configuration.width = Self.captureSide
            configuration.height = Self.captureSide
            configuration.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(display: display, excludingWindows: ownWindows),
                configuration: configuration)
            if let luminance = BackdropTone.averageLuminance(of: image) { onLuminance(luminance) }
        } catch {
            NSLog("usage-gauge: backdrop sampling stopped: \(error.localizedDescription)")
            stop()
            onUnavailable("화면 기록 권한이 없어 배경 맞춤을 쓰지 못해요")
        }
    }
}
