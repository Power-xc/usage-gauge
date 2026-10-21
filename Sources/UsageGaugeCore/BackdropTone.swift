import CoreGraphics
import Foundation

/// How dark the panel's glass should be for what sits behind it: deeper over bright content so
/// the type stays legible, clearer over dark content so the glass stays light.
public enum BackdropTone {
    public static let tintRange: ClosedRange<Double> = 0.36...0.76
    /// Glass tint when the backdrop cannot be read (e.g. a moving wallpaper).
    public static let fallbackTint = 0.54
    /// Below 1 the tint deepens quickly through mid-tones, where grey glass looks muddiest.
    private static let curve = 0.75

    private static let sampleSide = 8

    /// - Parameter luminance: 0 (black) ... 1 (white) average brightness behind the panel.
    public static func tintOpacity(luminance: Double) -> Double {
        let clamped = min(1, max(0, luminance))
        return tintRange.lowerBound + (tintRange.upperBound - tintRange.lowerBound) * pow(clamped, curve)
    }

    /// The part of the wallpaper image that sits behind the panel, in image pixels (top-left
    /// origin). macOS fills the screen with the wallpaper, scaling it to cover and centring it.
    /// - Parameters:
    ///   - panel: the panel's frame and `screen` the screen's frame, both in AppKit coordinates.
    public static func wallpaperRegion(behind panel: CGRect, on screen: CGRect, imageSize: CGSize) -> CGRect {
        guard screen.width > 0, screen.height > 0, imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = max(screen.width / imageSize.width, screen.height / imageSize.height)
        let overflowX = (imageSize.width * scale - screen.width) / 2
        let overflowY = (imageSize.height * scale - screen.height) / 2
        let fromLeft = panel.minX - screen.minX
        let fromTop = screen.maxY - panel.maxY
        let region = CGRect(x: (fromLeft + overflowX) / scale, y: (fromTop + overflowY) / scale,
                            width: panel.width / scale, height: panel.height / scale)
        let clipped = region.intersection(CGRect(origin: .zero, size: imageSize)).integral
        return clipped.isNull ? .zero : clipped
    }

    /// Average brightness of an image, 0...1, measured on a tiny greyscale copy.
    public static func averageLuminance(of image: CGImage) -> Double? {
        let side = sampleSide
        var pixels = [UInt8](repeating: 0, count: side * side)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        return Double(pixels.reduce(0) { $0 + Int($1) }) / Double(side * side * 255)
    }
}
