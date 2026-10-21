import SwiftUI
import UsageGaugeUI

/// The reel's cover for Instagram, 9:16: one claim over the real screen that backs it, with the
/// projection circled by hand, and nothing that reads as an ad (no name, no feature list, no
/// price). Everything sits inside the 3:4 band the profile grid shows, below the reel icon at the
/// grid tile's top right.
struct CoverScene: View {
    static let size = CGSize(width: 1080, height: 1920)
    private static let titleTop: CGFloat = 470
    private static let titleSize: CGFloat = 188
    /// The part of the two-tool trend panel shown, in its points: Codex's cell, from its name down
    /// to the curve running out.
    private static let focus = CGRect(x: 250, y: 82, width: 244, height: 186)
    private static let zoom: CGFloat = 4
    private static let closeUpTop: CGFloat = 900
    /// Where "28m 후 소진" sits in the panel, for the marker loop around it.
    private static let projection = CGRect(x: 327, y: 152, width: 54, height: 11)

    var body: some View {
        ZStack(alignment: .top) {
            Backdrop(watermarkSize: nil)
            Text(title)
                .font(.custom("Pretendard-ExtraBold", size: Self.titleSize)).tracking(-4)
                .lineSpacing(-12)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.top, Self.titleTop)
            closeUp.padding(.top, Self.closeUpTop)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }

    private var title: AttributedString {
        var text = AttributedString("한도 터지기\n28분 전")
        if let range = text.range(of: "28분") { text[range].foregroundColor = Theme.critical }
        return text
    }

    /// The real panel, enlarged on the focus and fading out at every edge so it reads as a crop of
    /// a screen rather than a framed picture.
    private var closeUp: some View {
        let size = CGSize(width: Self.focus.width * Self.zoom, height: Self.focus.height * Self.zoom)
        let loop = Self.projection.insetBy(dx: -9, dy: -8)
        return ZStack(alignment: .topLeading) {
            SamplePanel(tools: Array(SampleData.tools.prefix(2)), layout: .trend)
                .scaleEffect(Self.zoom, anchor: .topLeading)
                .offset(x: -Self.focus.minX * Self.zoom, y: -Self.focus.minY * Self.zoom)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .clipped()
                .mask(SoftEdges())
            MarkerLoop()
                .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .frame(width: loop.width * Self.zoom, height: loop.height * Self.zoom)
                .rotationEffect(.degrees(-3))
                .offset(x: (loop.minX - Self.focus.minX) * Self.zoom, y: (loop.minY - Self.focus.minY) * Self.zoom)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Opaque in the middle, clear at all four edges.
private struct SoftEdges: View {
    private static let fade = 0.05

    var body: some View {
        gradient(.top, .bottom).mask(gradient(.leading, .trailing))
    }

    private func gradient(_ start: UnitPoint, _ end: UnitPoint) -> LinearGradient {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: Self.fade),
                               .init(color: .black, location: 1 - Self.fade), .init(color: .clear, location: 1)],
                       startPoint: start, endPoint: end)
    }
}

/// A marker loop drawn by hand: a little more than one turn that wobbles and drifts outward, so
/// it reads as someone's note on a screenshot rather than part of the design.
private struct MarkerLoop: Shape {
    private static let turns = 1.12
    private static let steps = 160

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for step in 0...Self.steps {
            let t = Double(step) / Double(Self.steps)
            let angle = -0.62 * Double.pi + t * Self.turns * 2 * Double.pi
            let wobble = 1 + 0.03 * sin(t * 5 * Double.pi) + 0.06 * t
            let point = CGPoint(x: rect.midX + cos(angle) * rect.width / 2 * wobble,
                                y: rect.midY + sin(angle) * rect.height / 2 * wobble)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
