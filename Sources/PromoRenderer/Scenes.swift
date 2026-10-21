import SwiftUI
import UsageGaugeCore
import UsageGaugeUI

/// Static hero image: menu bar strip + panel on a dark desktop.
struct PreviewScene: View {
    static let size = CGSize(width: 1200, height: 720)

    var body: some View {
        ZStack(alignment: .top) {
            Backdrop()
            MenuBarStrip(providers: SampleData.still, width: Self.size.width)
            GaugeView(providers: SampleData.still, status: "오후 12:04 기준", now: SampleData.now, onClose: {}, opacity: .constant(1), frozenAt: 3)
                .modifier(RenderedGlass())
                .padding(.top, 150)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }
}

/// Every connected provider in one panel.
struct AllProvidersScene: View {
    static let size = CGSize(width: 640, height: 520)

    var body: some View {
        ZStack {
            Backdrop()
            GaugeView(providers: SampleData.still + SampleData.extras(scale: 1), status: "오후 12:04 기준",
                      now: SampleData.now, onClose: {}, opacity: .constant(1), frozenAt: 6)
                .modifier(RenderedGlass())
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }
}

/// The three styles stacked, same numbers in each.
struct StylesScene: View {
    static let size = CGSize(width: 640, height: 600)

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 28) {
                ForEach(PanelStyle.allCases, id: \.self) { style in
                    GaugeView(providers: SampleData.still, status: "오후 12:04 기준", now: SampleData.now, onClose: {},
                              opacity: .constant(1), style: style, frozenAt: 3)
                        .modifier(RenderedSurface(style: style))
                }
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }
}

/// The mono panel at three sizes, stacked.
struct SizesScene: View {
    static let size = CGSize(width: 1160, height: 760)
    private static let scales = [0.8, 1.0, 1.4]

    var body: some View {
        ZStack {
            Backdrop()
            VStack(alignment: .leading, spacing: 28) {
                ForEach(Self.scales, id: \.self) { scale in
                    GaugeView(providers: Array(SampleData.still.prefix(2)), status: "오후 12:04 기준", now: SampleData.now,
                              onClose: {}, opacity: .constant(1), style: .mono, frozenAt: 3)
                        .modifier(RenderedSurface(style: .mono))
                        .panelScale(scale)
                }
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }
}

/// The menu bar companion on its own, enlarged.
struct MenuBarScene: View {
    static let size = CGSize(width: 1280, height: 240)

    var body: some View {
        ZStack {
            Backdrop()
            MenuBarStrip(providers: SampleData.still, width: 600)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(GlassEdge.gradient, lineWidth: 0.6))
                .scaleEffect(2)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }
}

/// The three levels side by side: comfortable, low (≤ 30%), critical (≤ 10%).
struct LevelsScene: View {
    static let size = CGSize(width: 640, height: 340)

    var body: some View {
        ZStack {
            Backdrop()
            HStack(spacing: 28) {
                level(72, "여유", "claude")
                level(24, "30% 이하", "codex")
                level(6, "10% 이하", "gemini")
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private func level(_ remaining: Double, _ title: String, _ provider: String) -> some View {
        VStack(spacing: 18) {
            SessionGauge(window: SampleData.window(remaining: remaining, minutes: 300, resetIn: 3600),
                         tint: Theme.brand(for: provider), size: 172, now: SampleData.now, frozenAt: 4)
            Text(title).font(Theme.font(16, .semibold)).foregroundStyle(Theme.mutedText)
        }
    }
}

/// README loop: the same four tools in each style in turn — iris, dot, mono — each filling in and
/// one tool draining into the warning colours, with the style's name underneath.
struct ReadmeScene: View {
    static let size = CGSize(width: 800, height: 400)
    static let phase = 4.0
    static let duration = phase * Double(PanelStyle.allCases.count)
    private static let fade = 0.45

    let time: Double

    var body: some View {
        ZStack(alignment: .top) {
            Backdrop()
            // The menu bar holds steady while the panel changes style above it.
            MenuBarStrip(providers: Array(providers(at: Self.phase / 2).prefix(3)), width: Self.size.width)
            ForEach(Array(PanelStyle.allCases.enumerated()), id: \.element) { index, style in
                let start = Double(index) * Self.phase
                let local = time - start
                let visibility = Motion.visibility(time, start: start - Self.fade / 2, end: start + Self.phase + Self.fade / 2,
                                                   fade: Self.fade)
                    + (index == 0 ? Motion.visibility(time, start: Self.duration - Self.fade / 2,
                                                      end: Self.duration + Self.phase, fade: Self.fade) : 0)
                if visibility > 0 {
                    VStack(spacing: 22) {
                        GaugeView(providers: providers(at: local < 0 ? local + Self.duration : local), status: "오후 12:04 기준",
                                  now: SampleData.now, onClose: {}, opacity: .constant(1), style: style, frozenAt: time)
                            .modifier(RenderedSurface(style: style))
                        GlassChip {
                            Text(style.title).font(Theme.font(13, .semibold)).foregroundStyle(Theme.mutedText)
                        }
                    }
                    .padding(.top, 74)
                    .opacity(visibility)
                    .blur(radius: (1 - visibility) * 6)
                }
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }

    /// Values for one phase: everything fills in, then Codex and Cursor drain into the warning colours.
    private func providers(at local: Double) -> [ProviderUsage] {
        let fill = Motion.progress(local, from: 0.1, to: 1.6)
        let drain = Motion.progress(local, from: 2.0, to: 3.4)
        let others = SampleData.extras(scale: fill)
        return [
            SampleData.claude(session: 94 * fill, weekly: 37 * fill),
            SampleData.codex(session: Motion.mix(62, 8, drain) * fill, weekly: 26 * fill),
            others[0],
            SampleData.cursor(session: Motion.mix(46, 22, drain) * fill, weekly: 53 * fill),
        ]
    }
}

/// Vertical 9:16 reel for Instagram. Captions sit in the upper middle and the visuals in the
/// centre, clear of the app's own name bar at the top and caption and buttons at the bottom.
struct ReelScene: View {
    static let size = CGSize(width: 1080, height: 1920)
    static let duration = 21.0
    private static let styleTurns: [(style: PanelStyle, start: Double)] = [(.mono, 0), (.iris, 12.0), (.dot, 13.6)]
    /// Where the panel leaves and the menu bar close-up takes over.
    private static let panelExit = 15.2

    let time: Double

    var body: some View {
        ZStack {
            Backdrop()
            hook.opacity(1 - Motion.progress(time, from: 2.9, to: 3.4))
            caption.offset(y: -440)
            panel
            menuBarFocus
            outro.opacity(Motion.progress(time, from: 17.8, to: 18.5))
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    // 0 – 3.4 s: the dial starts full (the cover), drains into the warning colours and refills.
    private var hook: some View {
        let drain = Motion.progress(time, from: 0.6, to: 1.7)
        let refill = Motion.progress(time, from: 1.9, to: 3.0)
        let window = SampleData.window(remaining: Motion.mix(Motion.mix(94, 18, drain), 94, refill), minutes: 300, resetIn: 230 * 60)
        return VStack(spacing: 96) {
            SessionGauge(window: window, tint: Theme.brand(for: "claude"), size: 560, now: SampleData.now, frozenAt: time)
            VStack(spacing: 18) {
                Text("AI 코딩 한도,").font(Theme.font(84, .bold))
                Text("이제 한눈에").font(Theme.font(84, .bold)).foregroundStyle(Theme.mutedText)
            }
        }
        .foregroundStyle(.white)
    }

    // 3.4 – 17.6 s: one caption at a time, a headline over a quieter line.
    private var caption: some View {
        let lines: [(start: Double, end: Double, title: String, detail: String)] = [
            (3.4, 7.2, "쓰는 모든 AI의 남은 한도", "Claude · Codex · Gemini · Cursor …"),
            (7.2, 10.4, "줄어들면 숫자가 먼저", "30% 이하 노랑 · 10% 이하 산호색"),
            (10.4, 15.0, "스타일 3종, 취향대로", "모노 터미널 · 홍채 · 도트 매트릭스"),
            (15.4, 17.6, "메뉴바에도 항상", "⌥⌘U 로 켜고 끄기"),
        ]
        return ZStack {
            ForEach(lines, id: \.title) { line in
                VStack(spacing: 18) {
                    Text(line.title).font(Theme.font(64, .bold)).foregroundStyle(.white)
                    Text(line.detail).font(Theme.font(32, .medium)).foregroundStyle(Theme.mutedText)
                }
                .opacity(Motion.visibility(time, start: line.start, end: line.end, fade: 0.45))
                .offset(y: 12 * (1 - Motion.progress(time, from: line.start, to: line.start + 0.45)))
            }
        }
    }

    // 3.0 – 15.2 s: the panel enters, fills, one tool drains, then it changes style twice.
    private var panel: some View {
        let enter = Motion.progress(time, from: 3.0, to: 4.0)
        let exit = Motion.progress(time, from: Self.panelExit - 0.6, to: Self.panelExit)
        return ZStack {
            ForEach(Array(Self.styleTurns.enumerated()), id: \.element.style) { index, turn in
                let next = index + 1 < Self.styleTurns.count ? Self.styleTurns[index + 1].start : 99
                let shown = Motion.progress(time, from: turn.start - 0.25, to: turn.start + 0.25)
                    * (1 - Motion.progress(time, from: next - 0.25, to: next + 0.25))
                if shown > 0 {
                    VStack(spacing: 30) {
                        GaugeView(providers: providers, status: "오후 12:04 기준", now: SampleData.now, onClose: {},
                                  opacity: .constant(1), style: turn.style, frozenAt: time)
                            .modifier(RenderedSurface(style: turn.style))
                            .scaleEffect(1.95)
                            .frame(height: 440)
                        GlassChip {
                            Text(turn.style.title).font(Theme.font(28, .semibold)).foregroundStyle(Theme.mutedText)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                        }
                        .opacity(Motion.progress(time, from: 10.6, to: 11.0))
                    }
                    .opacity(shown)
                    .blur(radius: (1 - shown) * 10)
                }
            }
        }
        .scaleEffect(Motion.mix(0.94, 1, enter) * Motion.mix(1, 0.94, exit))
        .opacity(enter * (1 - exit))
        .blur(radius: (1 - enter) * 16 + exit * 10)
    }

    private var providers: [ProviderUsage] {
        let fill = Motion.progress(time, from: 3.4, to: 5.2)
        let drain = Motion.progress(time, from: 7.6, to: 9.6)
        let others = SampleData.extras(scale: fill)
        return [
            SampleData.claude(session: 94 * fill, weekly: 37 * fill),
            SampleData.codex(session: Motion.mix(62, 8, drain) * fill, weekly: 26 * fill),
            others[0],
            SampleData.cursor(session: Motion.mix(46, 24, drain) * fill, weekly: 53 * fill),
        ]
    }

    // 15.4 – 17.6 s: the menu bar companion, enlarged.
    private var menuBarFocus: some View {
        let show = Motion.progress(time, from: 15.4, to: 16.0) * (1 - Motion.progress(time, from: 17.2, to: 17.7))
        let providers = [SampleData.claude(session: 94, weekly: 37), SampleData.codex(session: 8, weekly: 26)]
        return MenuBarView(providers: providers)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.smoke.opacity(0.6)))
            .overlay(Capsule().strokeBorder(GlassEdge.gradient, lineWidth: 0.6))
            .scaleEffect(Motion.mix(2.9, 3.1, show))
            .opacity(show)
            .blur(radius: (1 - show) * 10)
    }

    // 17.8 – 21 s: name, platforms and the call to action.
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
    }
}

/// Fake macOS menu bar with the real `MenuBarView`.
struct MenuBarStrip: View {
    let providers: [ProviderUsage]
    let width: CGFloat

    var body: some View {
        HStack(spacing: 16) {
            Spacer()
            MenuBarView(providers: providers)
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("10월 21일 (화) 오후 12:04").font(Theme.font(12, .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(width: width, height: 30)
        .background(Color.black.opacity(0.32))
    }
}


/// The four layouts in the mono style, then bars and columns in iris and dot; same numbers throughout.
struct LayoutsScene: View {
    static let size = CGSize(width: 1160, height: 1200)

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 28) {
                HStack(alignment: .top, spacing: 28) {
                    VStack(spacing: 28) { panel(.mono, .dial); panel(.mono, .columns) }
                    VStack(spacing: 28) { panel(.mono, .bars); panel(.mono, .figures) }
                }
                HStack(alignment: .top, spacing: 28) {
                    VStack(spacing: 28) { panel(.iris, .bars); panel(.dot, .bars) }
                    VStack(spacing: 28) { panel(.iris, .columns); panel(.dot, .columns) }
                }
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }

    private func panel(_ style: PanelStyle, _ layout: PanelLayout) -> some View {
        GaugeView(providers: SampleData.still + SampleData.extras(scale: 1).prefix(2), status: "오후 12:04 기준",
                  now: SampleData.now, onClose: {}, opacity: .constant(1), style: style, layout: layout, frozenAt: 3)
            .modifier(RenderedSurface(style: style))
    }
}

/// The orbit and capsule layouts, each in mono, iris and dot, with four tools; orbit also with two
/// and with six.
struct ShapeLayoutsScene: View {
    static let size = CGSize(width: 1160, height: 1620)

    var body: some View {
        ZStack {
            Backdrop()
            HStack(alignment: .top, spacing: 28) {
                VStack(spacing: 28) { ForEach(PanelStyle.allCases, id: \.self) { panel($0, .orbit, tools: four) } }
                VStack(spacing: 28) {
                    ForEach(PanelStyle.allCases, id: \.self) { panel($0, .capsule, tools: four) }
                    panel(.iris, .orbit, tools: Array(four.prefix(2)))
                    panel(.dot, .orbit, tools: four + SampleData.extras(scale: 1).suffix(1) + [windsurf])
                }
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }

    private var four: [ProviderUsage] { SampleData.still + SampleData.extras(scale: 1).prefix(2) }

    private var windsurf: ProviderUsage {
        ProviderUsage(id: "windsurf", plan: "Pro", session: SampleData.window(remaining: 60, minutes: 300, resetIn: 200 * 60),
                      weekly: SampleData.window(remaining: 40, minutes: 10080, resetIn: 90 * 3600))
    }

    private func panel(_ style: PanelStyle, _ layout: PanelLayout, tools: [ProviderUsage]) -> some View {
        GaugeView(providers: tools, status: "오후 12:04 기준", now: SampleData.now, onClose: {}, opacity: .constant(1),
                  style: style, layout: layout, frozenAt: 3)
            .modifier(RenderedSurface(style: style))
    }
}

/// The trend layout in mono, iris and dot over the sample histories.
struct TrendScene: View {
    static let size = CGSize(width: 1160, height: 1000)

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 28) {
                HStack(alignment: .top, spacing: 28) {
                    panel(.mono)
                    panel(.iris)
                }
                panel(.dot)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }

    private func panel(_ style: PanelStyle) -> some View {
        GaugeView(providers: SampleData.still + SampleData.extras(scale: 1).prefix(2), status: "오후 12:04 기준",
                  now: SampleData.now, onClose: {}, opacity: .constant(1), style: style, layout: .trend,
                  history: SampleData.history, frozenAt: 3)
            .modifier(RenderedSurface(style: style))
    }
}

/// The two history layouts in each style; the sample history stands in for what the app records.
struct HistoryBarsScene: View {
    static let size = CGSize(width: 1160, height: 1560)

    var body: some View {
        ZStack {
            Backdrop()
            HStack(alignment: .top, spacing: 28) {
                column(.histogram)
                column(.spark)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }

    private func column(_ layout: PanelLayout) -> some View {
        VStack(spacing: 28) {
            ForEach([PanelStyle.mono, .iris, .dot], id: \.self) { style in
                GaugeView(providers: Array(SampleData.still + SampleData.extras(scale: 1).prefix(2)), status: "오후 12:04 기준",
                          now: SampleData.now, onClose: {}, opacity: .constant(1), style: style, layout: layout,
                          history: SampleData.history, frozenAt: 3)
                    .modifier(RenderedSurface(style: style))
            }
        }
    }
}

/// The interaction layer in each style: a tool's detail page under the tab row, and the overview
/// with a hovered cell revealing its reset and measuring times.
struct InteractionScene: View {
    static let size = CGSize(width: 1160, height: 1100)

    private static let providers = (SampleData.still + SampleData.extras(scale: 1).prefix(2)).map { usage in
        ProviderUsage(id: usage.id, plan: usage.plan, session: usage.session, weekly: usage.weekly,
                      measuredAt: SampleData.now.addingTimeInterval(-600))
    }

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 28) {
                ForEach(PanelStyle.allCases, id: \.self) { style in
                    HStack(alignment: .top, spacing: 28) {
                        panel(style, tool: "claude", hovered: nil)
                        panel(style, tool: nil, hovered: "codex")
                    }
                }
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }

    private func panel(_ style: PanelStyle, tool: String?, hovered: String?) -> some View {
        GaugeView(providers: Self.providers, status: "오후 12:04 기준", now: SampleData.now, onClose: {},
                  opacity: .constant(1), style: style, frozenAt: 3, onLayout: { _ in })
            .panelPreset(tool: tool, hovered: hovered)
            .modifier(RenderedSurface(style: style))
    }
}
