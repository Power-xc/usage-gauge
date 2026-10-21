import SwiftUI
import UsageGaugeUI

/// The reel's timeline in seconds: the subtitles, what the panels and the pointer do, and where
/// the camera looks. Eight tools fill up one after another while the camera moves down them, then
/// hand over to a two-tool panel the pointer uses; the eight come back for the outro in the
/// opening's shot and drain, so the loop starts again from empty.
enum ReelScript {
    static let duration = 30.0
    /// The stage the camera films: the menu bar on top, the panel under it.
    static let canvas = CGSize(width: 760, height: 600)
    static let handover = 5.4
    static let outro = 26.8

    /// The menu bar item's left edge and a point on it, where the menu opens and the pointer clicks.
    static let menuItemLeft: CGFloat = 186
    static let menuItem = CGPoint(x: 215, y: 15)
    static let menuOrigin = CGPoint(x: menuItemLeft, y: 33)

    static let lines: [ReelLine] = [
        ReelLine(start: 0.1, end: 2.7, title: "AI로 코딩한다면\n이것부터 깔아두세요", accent: "이것부터"),
        ReelLine(start: 2.75, end: 5.3, mark: "100+ AI", title: "쓰는 AI 한도,\n전부 한 화면에", accent: "전부",
                 detail: "Claude · Codex · Gemini · Cursor …"),
        ReelLine(start: 5.55, end: 8.3, mark: "소진 예측", title: "언제 바닥나는지까지\n미리 알려줘요", accent: "바닥나는지",
                 detail: "지금 속도면 28분 후 소진"),
        ReelLine(start: 8.75, end: 13.5, live: .graph, title: "그래프 12종", accent: "12종",
                 detail: "다이얼 · 바 · 궤도 · 별자리 · 추이 …"),
        ReelLine(start: 13.65, end: 15.9, live: .style, title: "스타일 3종", accent: "3종",
                 detail: "모노 터미널 · 홍채 글래스 · 도트 매트릭스"),
        ReelLine(start: 16.05, end: 18.5, mark: "탭 · 마우스 오버", title: "누르면 상세,\n올리면 초기화 시각", accent: "초기화 시각"),
        ReelLine(start: 18.65, end: 21.3, mark: "크기 · 투명도", title: "끌어서 바로 조절", accent: "끌어서",
                 detail: "크기 0.7–1.6배 · 투명도 30–100%"),
        ReelLine(start: 21.45, end: 24.3, mark: "메뉴", title: "메뉴 하나로 전부", accent: "전부",
                 detail: "그래프 · 스타일 · 투명도 · 크기까지"),
        ReelLine(start: 24.45, end: 26.7, mark: "상단바", title: "패널을 꺼도\n상단바에 그대로", accent: "상단바",
                 detail: "서비스마다 막대 두 줄과 남은 %"),
    ]

    /// The opening and the outro: eight tools on the dial form, filling in turn and finally draining.
    static let lineup = DemoScript(
        duration: duration, faces: [(0, PanelFace())], stops: [], scale: Track(keys: [(0, 1)]),
        fill: FillPlan(start: 0.15, duration: 0.9, stagger: 0.42, resetAt: 29.3, resetDuration: 0.55))

    /// The camera's keys: zoom and the stage point at the middle of the picture.
    static let camera: [(at: Double, zoom: Double, center: CGPoint)] = {
        let top = CGPoint(x: 380, y: 194), panel = CGPoint(x: 380, y: 186)
        let menu = menuItemLeft
        return [
            (0, 1.75, top), (1.6, 1.75, top),
            (4.6, 1.75, CGPoint(x: 380, y: 318)), (5.2, 1.75, CGPoint(x: 380, y: 318)),
            (5.7, 1.85, panel), (6.3, 1.85, panel),
            (6.75, 2.9, CGPoint(x: 444, y: 205)), (7.8, 2.9, CGPoint(x: 444, y: 205)),
            (8.3, 1.85, panel), (17.45, 1.85, panel),
            (17.85, 2.9, CGPoint(x: 480, y: 165)), (18.45, 2.9, CGPoint(x: 480, y: 165)),
            (18.85, 1.75, CGPoint(x: 380, y: 200)), (21.55, 1.75, CGPoint(x: 380, y: 200)),
            (22.05, 2.0, CGPoint(x: menu + 190, y: 160)), (22.55, 2.0, CGPoint(x: menu + 190, y: 160)),
            (23.0, 2.0, CGPoint(x: menu + 230, y: 235)), (23.35, 2.0, CGPoint(x: menu + 230, y: 235)),
            (23.8, 1.85, panel), (24.5, 1.85, panel),
            (24.95, 3.0, CGPoint(x: menu + 176, y: 15)), (26.55, 3.0, CGPoint(x: menu + 176, y: 15)),
            (27.0, 1.75, top),
        ]
    }()

    /// Zoom and centre at `time`, eased from key to key; zoom moves evenly in scale, not in size.
    static func camera(at time: Double) -> (zoom: Double, center: CGPoint) {
        guard let next = camera.firstIndex(where: { $0.at > time }) else {
            return (camera[camera.count - 1].zoom, camera[camera.count - 1].center)
        }
        guard next > 0 else { return (camera[0].zoom, camera[0].center) }
        let from = camera[next - 1], to = camera[next]
        let amount = Motion.progress(time, from: from.at, to: to.at)
        let zoom = exp(Motion.mix(log(from.zoom), log(to.zoom), amount))
        let center = CGPoint(x: Motion.mix(from.center.x, to.center.x, amount),
                             y: Motion.mix(from.center.y, to.center.y, amount))
        return (zoom, center)
    }

    /// How full the menu bar's n-th tool is: it fills and drains with the line-up, and once the
    /// panel is hidden it empties and counts up again under the camera, one tool after another.
    static func menuBarAmount(at time: Double, index: Int) -> Double {
        let reveal = 24.95 + 0.22 * Double(index)
        let recount = 1 - Motion.progress(time, from: 24.7, to: 24.85) + Motion.progress(time, from: reveal, to: reveal + 0.8)
        return (lineup.fill?.amount(at: time, index: index) ?? 1) * min(1, recount)
    }

    /// The graph the reel's subtitle names: the one about to be clicked before the picker starts.
    static func graphOnShow(at time: Double) -> PanelLayout {
        time < graphTime(0) ? PanelLayout.allCases[0] : demo.face(at: time).current.layout
    }
}
