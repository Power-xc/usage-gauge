import CoreGraphics
import Foundation

/// How dark the panel's glass should be for what sits behind it: deeper over bright content so
/// the type stays legible, clearer over dark content so the glass stays light.
public enum BackdropTone {
    public static let tintRange: ClosedRange<Double> = 0.36...0.76
    /// Glass tint when the backdrop cannot be read (no screen-recording permission).
    public static let fallbackTint = 0.54
    /// Below 1 the tint deepens quickly through mid-tones, where grey glass looks muddiest.
    private static let curve = 0.75

    private static let sampleSide = 8

    /// - Parameter luminance: 0 (black) ... 1 (white) average brightness behind the panel.
    public static func tintOpacity(luminance: Double) -> Double {
        let clamped = min(1, max(0, luminance))
        return tintRange.lowerBound + (tintRange.upperBound - tintRange.lowerBound) * pow(clamped, curve)
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
