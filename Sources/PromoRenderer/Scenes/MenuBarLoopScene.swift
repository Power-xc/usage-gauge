import SwiftUI
import UsageGaugeCore
import UsageGaugeUI

/// The menu bar strip on its own: every tool's bars and figure fill up from empty, hold, drain
/// together and start again. Wide and short, for the top of the README.
struct MenuBarLoopScene: View {
    static let size = CGSize(width: 800, height: 80)
    static let fps = 25.0
    static let fill = FillPlan(start: 0.15, duration: 1.3, stagger: 0.18, resetAt: 4.1, resetDuration: 0.7)
    static let duration = 5.0
    /// The strip is laid out at its natural size and zoomed to fill the picture.
    private static let zoom: CGFloat = 1.7
    private static let stripHeight: CGFloat = 52
    /// Each one-tool strip brings 8 pt of padding on both sides; −2 closes neighbours to the real
    /// strip's 14 pt gap.
    private static let itemGap: CGFloat = -2

    let time: Double

    var body: some View {
        let filled = Self.fill.apply(to: SampleData.tools, at: time)
        ZStack {
            Backdrop(watermarkSize: nil)
            Color.white.opacity(0.07).frame(height: Self.stripHeight)
            // Every tool sits in a slot as wide as its full figure, hidden, and fills it from the
            // left, so names and bars stay put while only the figures count up and down.
            HStack(spacing: Self.itemGap) {
                ForEach(SampleData.tools.indices, id: \.self) { index in
                    ZStack(alignment: .leading) {
                        MenuBarView(providers: [SampleData.tools[index]]).hidden()
                        MenuBarView(providers: [filled[index]])
                    }
                }
            }
            .fixedSize()
            .foregroundStyle(.white)
            .scaleEffect(Self.zoom)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }
}
