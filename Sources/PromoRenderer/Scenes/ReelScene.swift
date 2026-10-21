import SwiftUI
import UsageGaugeCore
import UsageGaugeUI

/// Vertical 9:16 reel for Instagram: the app filmed in the upper half and large subtitles under
/// it, both inside the area Instagram leaves clear of its header, caption and buttons.
struct ReelScene: View {
    static let size = CGSize(width: 1080, height: 1920)
    static let duration = ReelScript.duration
    private static let videoTop: CGFloat = 200
    private static let videoHeight: CGFloat = 680
    private static let captionTop: CGFloat = 910
    /// The menu bar shows the first three tools of the line-up, filling and draining with them.
    private static let menuBarTools = Array(SampleData.lineup.prefix(3))

    let time: Double

    var body: some View {
        ZStack(alignment: .top) {
            Backdrop(watermarkSize: nil)
            video
                .frame(width: Self.size.width, height: Self.videoHeight)
                .mask(EdgeFade())
                .padding(.top, Self.videoTop)
            captions.padding(.top, Self.captionTop)
            ReelOutro(time: time).padding(.top, Self.captionTop)
            // The author's name sits in the gap between the filmed area and the subtitles.
            Watermark(size: 20)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 72)
                .padding(.top, Self.videoTop + Self.videoHeight + 2)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    /// The stage under the camera. The line-up leaves before the two-tool panel arrives, and comes
    /// back after it leaves, so the two never show through each other.
    private var video: some View {
        let camera = ReelScript.camera(at: time)
        let canvas = ReelScript.canvas
        let handover = ReelScript.handover, outro = ReelScript.outro
        let lineup = max(1 - Motion.progress(time, from: handover - 0.25, to: handover),
                         Motion.progress(time, from: outro, to: outro + 0.35))
        let demo = Motion.progress(time, from: handover, to: handover + 0.3)
            * (1 - Motion.progress(time, from: outro - 0.25, to: outro))
        let menuBar = FillPlan.scale(Self.menuBarTools) { ReelScript.menuBarAmount(at: time, index: $0) }
        return ZStack(alignment: .topLeading) {
            MenuBarStrip(providers: menuBar, width: canvas.width)
            DemoStage(script: ReelScript.lineup, time: time, canvas: canvas, tools: SampleData.lineup,
                      showsBackdrop: false, showsMenuBar: false, showsPointer: false)
                .opacity(lineup)
            DemoStage(script: ReelScript.demo, time: time, canvas: canvas, showsBackdrop: false, showsMenuBar: false)
                .opacity(demo)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .scaleEffect(camera.zoom, anchor: .topLeading)
        .offset(x: Self.size.width / 2 - camera.center.x * camera.zoom,
                y: Self.videoHeight / 2 - camera.center.y * camera.zoom)
        .frame(width: Self.size.width, height: Self.videoHeight, alignment: .topLeading)
    }

    private var captions: some View {
        ZStack(alignment: .top) {
            ForEach(Array(ReelScript.lines.enumerated()), id: \.offset) { _, line in
                if time >= line.start && time < line.end {
                    ReelCaption(line: live(line), time: time)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// A line with its chapter mark following the panel: the graph or the style on show.
    private func live(_ line: ReelLine) -> ReelLine {
        guard let live = line.live else { return line }
        var shown = line
        switch live {
        case .graph:
            let layout = ReelScript.graphOnShow(at: time)
            let index = (PanelLayout.allCases.firstIndex(of: layout) ?? 0) + 1
            shown.mark = String(format: "%02d / 12  ·  %@", index, layout.title)
        case .style:
            shown.mark = ReelScript.demo.face(at: time).current.style.title
        }
        return shown
    }
}

/// Fades the filmed area out at its top and bottom edges, so whatever the camera leaves at the
/// border dissolves into the page instead of ending on a hard line.
private struct EdgeFade: View {
    var body: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.04),
                               .init(color: .black, location: 0.96), .init(color: .clear, location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// The closing card: free and open source, the platforms and the call to action, rising in like
/// the subtitles.
private struct ReelOutro: View {
    let time: Double

    var body: some View {
        let start = ReelScript.outro + 0.15
        let line = ReelLine(start: start, end: ReelScript.duration + 1, mark: "usage-gauge", title: "무료 · 오픈소스",
                            accent: "무료", detail: "macOS · Windows")
        let call = Motion.rise(time, from: start + 0.45, to: start + 0.8)
        VStack(spacing: 0) {
            if time >= start {
                ReelCaption(line: line, time: time)
                callToAction
                    .opacity(call)
                    .offset(y: 26 * (1 - call))
                    .padding(.top, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(1 - Motion.progress(time, from: ReelScript.duration - 0.45, to: ReelScript.duration - 0.05))
    }

    private var callToAction: some View {
        var title = AttributedString("팔로우 + 댓글 「링크」")
        if let range = title.range(of: "「링크」") { title[range].foregroundColor = Theme.accent }
        return VStack(spacing: 12) {
            Text(title).font(.custom("Pretendard-ExtraBold", size: 54)).tracking(-1)
            Text("DM으로 바로 보내드려요").font(.custom("Pretendard-SemiBold", size: 34))
                .foregroundStyle(.white.opacity(0.6))
        }
        .foregroundStyle(.white)
    }
}
