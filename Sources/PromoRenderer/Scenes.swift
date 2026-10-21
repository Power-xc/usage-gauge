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

/// Vertical 9:16 reel for Instagram.
struct ReelScene: View {
    static let size = CGSize(width: 1080, height: 1920)
    static let duration = 18.0

    let time: Double

    var body: some View {
        ZStack {
            Backdrop()
            intro.opacity(Motion.visibility(time, start: 0, end: 3.4, fade: 0.6))
            caption.offset(y: -620)
            panel.offset(y: 80)
            menuBarFocus.offset(y: 40)
            outro.opacity(Motion.progress(time, from: 14.8, to: 15.6))
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    // 0 – 3.4 s: the gauge fills up under the headline.
    private var intro: some View {
        let fill = Motion.progress(time, from: 0.3, to: 2.6)
        let window = SampleData.window(remaining: 94 * fill, minutes: 300, resetIn: 230 * 60)
        return VStack(spacing: 110) {
            SessionGauge(window: window, tint: Theme.brand(for: "claude"), size: 600, now: SampleData.now, frozenAt: time)
                .scaleEffect(Motion.mix(0.9, 1, Motion.progress(time, from: 0, to: 2.6)))
            VStack(spacing: 22) {
                Text("AI 코딩 한도,").font(Theme.font(80, .bold))
                Text("이제 한눈에").font(Theme.font(80, .bold)).foregroundStyle(Theme.accent)
            }
        }
        .foregroundStyle(.white)
    }

    // 3.4 – 15 s: one line at a time above the visual.
    private var caption: some View {
        let lines: [(start: Double, end: Double, text: String)] = [
            (3.4, 6.6, "Claude와 Codex 남은 한도를 실시간으로"),
            (6.6, 9.6, "줄어들수록 색으로 먼저 알려줘요"),
            (9.6, 12.4, "연결한 모든 AI 서비스까지 한 화면에"),
            (12.4, 15.0, "메뉴바에도 항상, ⌥⌘U로 켜고 끄기"),
        ]
        return ZStack {
            ForEach(lines, id: \.text) { line in
                Text(line.text)
                    .font(Theme.font(48, .bold))
                    .foregroundStyle(.white)
                    .opacity(Motion.visibility(time, start: line.start, end: line.end, fade: 0.4))
            }
        }
    }

    // 3.0 – 12.6 s: panel enters, one provider drains, then every provider joins.
    private var panel: some View {
        let enter = Motion.progress(time, from: 3.0, to: 4.2)
        let fill = Motion.progress(time, from: 3.6, to: 5.6)
        let drain = Motion.progress(time, from: 6.6, to: 8.8)
        let expand = Motion.progress(time, from: 9.6, to: 10.6)
        let exit = Motion.progress(time, from: 12.0, to: 12.7)
        var providers = [
            SampleData.claude(session: 94 * fill, weekly: 37 * fill),
            SampleData.codex(session: Motion.mix(62, 8, drain) * fill, weekly: 26 * fill),
        ]
        if expand > 0 { providers += SampleData.extras(scale: expand) }
        let scale = expand > 0 ? 1.42 : 2.0
        return GaugeView(providers: providers, status: "오후 12:04 기준", now: SampleData.now, frozenAt: time)
            .modifier(RenderedGlass())
            .scaleEffect(scale * Motion.mix(0.94, 1, enter) * Motion.mix(1, 0.92, exit))
            .opacity(enter * (1 - exit))
            .blur(radius: (1 - enter) * 18 + exit * 12)
    }

    // 12.4 – 15 s: the menu bar companion, enlarged.
    private var menuBarFocus: some View {
        let show = Motion.progress(time, from: 12.5, to: 13.2) * (1 - Motion.progress(time, from: 14.5, to: 15.1))
        let providers = [SampleData.claude(session: 94, weekly: 37), SampleData.codex(session: 8, weekly: 26)]
        return MenuBarView(providers: providers)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.smoke.opacity(0.5)))
            .overlay(Capsule().strokeBorder(GlassEdge.gradient, lineWidth: 0.6))
            .scaleEffect(Motion.mix(2.9, 3.2, show))
            .opacity(show)
            .blur(radius: (1 - show) * 10)
    }

    // 15 – 18 s: name and call to action.
    private var outro: some View {
        VStack(spacing: 40) {
            SessionGauge(window: SampleData.window(remaining: 94, minutes: 300, resetIn: 230 * 60), tint: Theme.brand(for: "claude"), size: 260, now: SampleData.now, frozenAt: time)
            Text("usage-gauge").font(Theme.font(88, .bold))
            Text("macOS · 무료 · 오픈소스").font(Theme.font(36, .medium)).foregroundStyle(Theme.mutedText)
            GlassChip {
                Text("팔로우 + 댓글 「링크」 → DM으로 보내드려요")
                    .font(Theme.font(34, .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .padding(.top, 30)
        }
        .foregroundStyle(.white)
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

