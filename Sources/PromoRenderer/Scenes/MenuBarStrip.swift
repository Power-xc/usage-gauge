import SwiftUI
import UsageGaugeCore
import UsageGaugeUI

/// Fake macOS menu bar with the real `MenuBarView`; the clock shows the sample moment.
struct MenuBarStrip: View {
    let providers: [ProviderUsage]
    let width: CGFloat

    var body: some View {
        HStack(spacing: 16) {
            Spacer()
            MenuBarView(providers: providers)
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text(SampleData.menuBarClock).font(Theme.font(12, .medium)).lineLimit(1).fixedSize()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(width: width, height: 30)
        .background(Color.white.opacity(0.07))
    }
}
