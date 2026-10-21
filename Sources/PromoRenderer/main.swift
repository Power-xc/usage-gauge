import AppKit
import SwiftUI

// Usage:
//   PromoRenderer preview <out.jpg|png>  static hero image
//   PromoRenderer stills  <dir>          all-providers, menu-bar and levels images
//   PromoRenderer readme  <frames-dir>   README loop frames (PNG sequence, encode with ffmpeg)
//   PromoRenderer reel    <frames-dir>   9:16 reel frames

/// JPEG keeps the README images light; the dark, soft renders show no visible artefacts at this level.
let jpegQuality = 0.9

/// Renders a view to an image file; the extension picks the format (.jpg/.jpeg or PNG).
@MainActor
func writeImage<V: View>(_ view: V, size: CGSize, scale: CGFloat, to url: URL) throws {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = scale
    guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
    let rep = NSBitmapImageRep(cgImage: image)
    let isJPEG = ["jpg", "jpeg"].contains(url.pathExtension.lowercased())
    let data = isJPEG ? rep.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality])
                      : rep.representation(using: .png, properties: [:])
    guard let data else { throw CocoaError(.fileWriteUnknown) }
    try data.write(to: url)
}

@MainActor
func writeFrames<V: View>(duration: Double, fps: Double, size: CGSize, scale: CGFloat, to directory: URL,
                          scene: (Double) -> V) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let count = Int(duration * fps)
    for index in 0..<count {
        let url = directory.appendingPathComponent(String(format: "frame-%04d.png", index))
        try writeImage(scene(Double(index) / fps), size: size, scale: scale, to: url)
        if index % Int(fps) == 0 { print("frame \(index)/\(count)") }
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("usage: PromoRenderer preview|readme|reel <output>")
    exit(2)
}
let output = URL(fileURLWithPath: arguments[2])

do {
    try MainActor.assumeIsolated {
        switch arguments[1] {
        case "preview":
            try writeImage(PreviewScene(), size: PreviewScene.size, scale: 2, to: output)
        case "stills":
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try writeImage(AllProvidersScene(), size: AllProvidersScene.size, scale: 2, to: output.appendingPathComponent("all-providers.jpg"))
            try writeImage(MenuBarScene(), size: MenuBarScene.size, scale: 2, to: output.appendingPathComponent("menu-bar.jpg"))
            try writeImage(LevelsScene(), size: LevelsScene.size, scale: 2, to: output.appendingPathComponent("levels.jpg"))
        case "readme":
            try writeFrames(duration: ReadmeScene.duration, fps: 20, size: ReadmeScene.size, scale: 2, to: output) { ReadmeScene(time: $0) }
        case "reel":
            try writeFrames(duration: ReelScene.duration, fps: 30, size: ReelScene.size, scale: 1, to: output) { ReelScene(time: $0) }
        default:
            print("unknown mode \(arguments[1])")
            exit(2)
        }
    }
} catch {
    FileHandle.standardError.write(Data("render failed: \(error)\n".utf8))
    exit(1)
}
