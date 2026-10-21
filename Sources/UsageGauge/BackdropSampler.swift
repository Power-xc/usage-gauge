import AppKit
import ImageIO
import UsageGaugeCore

/// Reads how bright the desktop wallpaper is behind the panel, so the glass can deepen over a
/// light wallpaper and clear over a dark one. It needs no permission: it reads the wallpaper
/// file, not the screen. Checks run when the panel moves, changes screen or Space, and every
/// few seconds to catch a new wallpaper.
@MainActor
final class BackdropSampler {
    private static let interval: TimeInterval = 10
    private static let thumbnailSide = 256

    private weak var window: NSWindow?
    private let onLuminance: (Double) -> Void
    private let onUnavailable: (String) -> Void
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var cached: (url: URL, image: CGImage)?

    init(window: NSWindow, onLuminance: @escaping (Double) -> Void, onUnavailable: @escaping (String) -> Void) {
        self.window = window
        self.onLuminance = onLuminance
        self.onUnavailable = onUnavailable
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(NotificationCenter.default, NSWindow.didMoveNotification, object: window)
        observe(NotificationCenter.default, NSWindow.didChangeScreenNotification, object: window)
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        sample()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        observers.forEach { center, token in center.removeObserver(token) }
        observers = []
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, object: AnyObject?) {
        let token = center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        observers.append((center, token))
    }

    private func sample() {
        guard let window, window.isVisible, let screen = window.screen else { return }
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen), let image = wallpaper(at: url) else {
            onUnavailable("바탕화면 이미지를 읽지 못해 기본 진하기로 표시해요")
            return
        }
        let size = CGSize(width: image.width, height: image.height)
        let region = BackdropTone.wallpaperRegion(behind: window.frame, on: screen.frame, imageSize: size)
        guard let crop = image.cropping(to: region), let luminance = BackdropTone.averageLuminance(of: crop) else {
            return
        }
        onLuminance(luminance)
    }

    /// A small decoded copy of the wallpaper, kept until the wallpaper changes.
    private func wallpaper(at url: URL) -> CGImage? {
        if let cached, cached.url == url { return cached.image }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceThumbnailMaxPixelSize: Self.thumbnailSide] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            NSLog("usage-gauge: could not read wallpaper at \(url.path)")
            return nil
        }
        cached = (url, image)
        return image
    }
}
