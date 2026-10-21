import AppKit
import SwiftUI

// Usage:
//   PromoRenderer stills <dir>          graphs, styles, interaction, menu-bar, sizes (.jpg) and social-preview (.png)
//   PromoRenderer readme <frames-dir>   README hero loop frames (PNG sequence, encode with ffmpeg)
//   PromoRenderer menubar <frames-dir>  menu bar strip filling up (PNG sequence, encode with ffmpeg)
//   PromoRenderer reel   <frames-dir> [fps]  9:16 reel frames (30 fps unless a lower rate is given for a quick look)

/// JPEG keeps the README images light; the dark, soft renders show no visible artefacts at this level.
let jpegQuality = 0.9

/// Renders a view to an image file; the extension picks the format (.jpg/.jpeg or PNG).
@MainActor
func writeImage<V: View>(_ view: V, size: CGSize? = nil, scale: CGFloat = 2, to url: URL) throws {
    // Without a size the scene is drawn at its natural size.
    let renderer = ImageRenderer(content: size.map { AnyView(view.frame(width: $0.width, height: $0.height)) } ?? AnyView(view.fixedSize()))
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
guard (3...4).contains(arguments.count) else {
    print("usage: PromoRenderer stills|readme|menubar|reel <output> [reel fps]")
    exit(2)
}
let output = URL(fileURLWithPath: arguments[2])

do {
    try MainActor.assumeIsolated {
        switch arguments[1] {
        case "stills":
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try writeImage(GraphsScene(), to: output.appendingPathComponent("graphs.jpg"))
            try writeImage(StylesScene(), to: output.appendingPathComponent("styles.jpg"))
            try writeImage(InteractionScene(), to: output.appendingPathComponent("interaction.jpg"))
            try writeImage(MenuBarScene(), size: MenuBarScene.size, to: output.appendingPathComponent("menu-bar.jpg"))
            try writeImage(SizesScene(), to: output.appendingPathComponent("sizes.jpg"))
            try writeImage(SocialPreviewScene(), size: SocialPreviewScene.size, scale: 1, to: output.appendingPathComponent("social-preview.png"))
        case "readme":
            try writeFrames(duration: ReadmeScene.duration, fps: ReadmeScene.fps, size: ReadmeScene.size, scale: 2, to: output) { ReadmeScene(time: $0) }
        case "menubar":
            try writeFrames(duration: MenuBarLoopScene.duration, fps: MenuBarLoopScene.fps, size: MenuBarLoopScene.size, scale: 2, to: output) { MenuBarLoopScene(time: $0) }
        case "reel":
            // Drawn at 2x and scaled down when encoding, so fine lines stay clean at 1080 × 1920.
            try writeFrames(duration: ReelScene.duration, fps: arguments.count == 4 ? Double(arguments[3]) ?? 30 : 30, size: ReelScene.size, scale: 2, to: output) { ReelScene(time: $0) }
        default:
            print("unknown mode \(arguments[1])")
            exit(2)
        }
    }
} catch {
    FileHandle.standardError.write(Data("render failed: \(error)\n".utf8))
    exit(1)
}
