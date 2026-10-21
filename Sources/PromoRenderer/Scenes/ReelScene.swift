import SwiftUI
import UsageGaugeCore
import UsageGaugeUI

/// Vertical 9:16 reel for Instagram. Captions sit in the upper safe area and the panel below
/// them, clear of the app's own bars at the top and its caption and buttons at the bottom; the
/// author's name sits top-left, where nothing of the app covers it.
struct ReelScene: View {
    static let size = CGSize(width: 1080, height: 1920)
    static let duration = DemoScript.Reel.duration
    /// The panel is laid out at 1x and zoomed so it fills the width of a phone.
    private static let zoom: CGFloat = 1.9
    private static let stageCanvas = CGSize(width: size.width / zoom, height: 640)
    private static let stageTop: CGFloat = 620
    private static let captionY: CGFloat = 400
    /// Where the panel changes from four tools filling and draining to the two the demo uses.
    private static let handover = 6.4

    let time: Double

    var body: some View {
        ZStack(alignment: .top) {
            Backdrop(watermarkSize: nil)
            hook.opacity(1 - Motion.progress(time, from: 2.5, to: 2.9))
            caption
            panel
            styleChip
            outro.opacity(Motion.progress(time, from: 18.5, to: 19.2))
            Watermark(size: 26).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 56).padding(.top, 150)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    // 0 – 2.9 s: the dial starts full (the cover), drains into the warning colours and refills.
    private var hook: some View {
        let drain = Motion.progress(time, from: 0.4, to: 1.3)
        let refill = Motion.progress(time, from: 1.5, to: 2.5)
        let window = SampleData.window(remaining: Motion.mix(Motion.mix(94, 18, drain), 94, refill), minutes: 300, resetIn: 230 * 60)
        return VStack(spacing: 96) {
            SessionGauge(window: window, tint: Theme.brand(for: "claude"), size: 560, now: SampleData.now, frozenAt: time)
            VStack(spacing: 18) {
                Text("AI 코딩 한도,").font(Theme.font(84, .bold))
                Text("이제 한눈에").font(Theme.font(84, .bold)).foregroundStyle(Theme.mutedText)
            }
        }
        .foregroundStyle(.white)
        .frame(maxHeight: .infinity)
    }

    // 2.9 – 18.4 s: one caption at a time, a headline over a quieter line.
    private var caption: some View {
        let reel = DemoScript.Reel.self
        let lines: [(start: Double, end: Double, title: String, detail: String)] = [
            (2.9, 5.0, "쓰는 모든 AI의 남은 한도", "Claude · Codex · Gemini · Cursor …"),
            (5.0, 6.4, "줄어들면 숫자가 먼저", "30% 이하 노랑 · 10% 이하 산호색"),
            (6.6, 13.1, "그래프 12종, 원하는 대로", "다이얼 · 바 · 숫자 · 추이 · 궤도 …"),
            (13.4, 15.1, "스타일 3종, 취향대로", "모노 터미널 · 홍채 · 도트 매트릭스"),
            (15.2, reel.end - 0.3, "탭으로 상세, 끌어서 크기", "눌러서 열고, 놓은 자리에서 조절"),
        ]
        return ZStack {
            ForEach(lines, id: \.title) { line in
                VStack(spacing: 18) {
                    Text(line.title).font(Theme.font(64, .bold)).foregroundStyle(.white)
                    Text(line.detail).font(Theme.font(32, .medium)).foregroundStyle(Theme.mutedText)
                }
                .opacity(Motion.visibility(time, start: line.start, end: line.end, fade: 0.35))
                .offset(y: 12 * (1 - Motion.progress(time, from: line.start, to: line.start + 0.35)))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, Self.captionY)
    }

    // 2.6 – 18.6 s: four tools fill and drain, then two of them are used with the pointer.
    private var panel: some View {
        let reel = DemoScript.Reel.self
        let enter = Motion.progress(time, from: 2.6, to: 3.4)
        let exit = Motion.progress(time, from: reel.end - 0.5, to: reel.end)
        let handing = Motion.progress(time, from: Self.handover - 0.3, to: Self.handover + 0.2)
        return ZStack(alignment: .topLeading) {
            stage(intro, tools: providers, showsPointer: false).opacity(1 - handing)
            stage(DemoScript.reel, tools: Array(SampleData.tools.prefix(2)), showsPointer: true).opacity(handing)
        }
        .padding(.top, Self.stageTop)
        .frame(maxHeight: .infinity, alignment: .top)
        .scaleEffect(Motion.mix(0.94, 1, enter) * Motion.mix(1, 0.94, exit), anchor: .center)
        .opacity(enter * (1 - exit))
        .blur(radius: (1 - enter) * 16 + exit * 10)
    }

    /// A stand-still script for the four-tool opening: the dial form on the starting size.
    private var intro: DemoScript {
        DemoScript(duration: Self.duration, faces: [(0, PanelFace())], stops: [],
                   scale: Track(keys: [(0, DemoScript.Reel.sizeRange.small)]))
    }

    private func stage(_ script: DemoScript, tools: [ProviderUsage], showsPointer: Bool) -> some View {
        DemoStage(script: script, time: time, canvas: Self.stageCanvas, tools: tools, showsDesktop: false, showsPointer: showsPointer)
            .scaleEffect(Self.zoom, anchor: .topLeading)
            .frame(width: Self.size.width, height: Self.stageCanvas.height * Self.zoom, alignment: .topLeading)
    }

    private var providers: [ProviderUsage] {
        let fill = Motion.progress(time, from: 3.0, to: 4.4)
        let drain = Motion.progress(time, from: 5.0, to: 6.2)
        let others = SampleData.extras(scale: fill)
        return SampleData.stamped([
            SampleData.claude(session: 94 * fill, weekly: 37 * fill),
            SampleData.codex(session: Motion.mix(62, 8, drain) * fill, weekly: 26 * fill),
            others[0],
            SampleData.cursor(session: Motion.mix(46, 24, drain) * fill, weekly: 53 * fill),
        ])
    }

    // 13.3 – 15.2 s: the name of the style on show, under the panel.
    private var styleChip: some View {
        let turns = [(PanelStyle.mono, DemoScript.Reel.pickerCloses)] + DemoScript.Reel.styles.map { ($0.style, $0.start) }
        let show = Motion.visibility(time, start: DemoScript.Reel.pickerCloses, end: DemoScript.Reel.styles[2].start, fade: 0.3)
        // The name changes as the panel's crossfade passes its middle.
        let current = turns.last { $0.1 + DemoScript.faceFade / 2 <= time }?.0 ?? .mono
        return GlassChip {
            Text(current.title).font(Theme.font(30, .semibold)).foregroundStyle(Theme.mutedText)
                .padding(.horizontal, 8).padding(.vertical, 4)
        }
        .opacity(show)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 1090)
    }

    // 18.5 – 22 s: name, platforms and the call to action.
    private var outro: some View {
        VStack(spacing: 36) {
            HStack(spacing: 28) {
                ForEach(PanelStyle.allCases, id: \.self) { style in
                    SessionGauge(window: SampleData.window(remaining: 94, minutes: 300, resetIn: 230 * 60),
                                 tint: Theme.brand(for: "claude"), size: 190, now: SampleData.now, frozenAt: time)
                        .environment(\.panelStyle, style)
                }
            }
            .padding(.bottom, 24)
            Text("usage-gauge").font(Theme.font(92, .bold))
            Text("macOS · Windows · 무료 오픈소스").font(Theme.font(36, .medium)).foregroundStyle(Theme.mutedText)
            GlassChip {
                Text("팔로우 + 댓글 「링크」 → DM으로 보내드려요")
                    .font(Theme.font(34, .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .padding(.top, 34)
        }
        .foregroundStyle(.white)
        .offset(y: -40)
        .frame(maxHeight: .infinity)
    }
}
