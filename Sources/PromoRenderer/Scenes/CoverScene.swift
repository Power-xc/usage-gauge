import SwiftUI
import UsageGaugeUI

/// The reel's cover for Instagram, 9:16. The title and the panel sit inside the middle 4:5 band
/// the feed shows and the 3:4 band the profile grid shows, so neither crop cuts them.
struct CoverScene: View {
    static let size = CGSize(width: 1080, height: 1920)
    private static let panelScale = 1.3

    var body: some View {
        ZStack {
            Backdrop(watermarkSize: nil)
            VStack(spacing: 0) {
                Text("usage-gauge")
                    .font(Theme.mono(26, .medium)).tracking(4)
                    .foregroundStyle(Theme.accent)
                    .padding(.bottom, 34)
                Text(title)
                    .font(.custom("Pretendard-ExtraBold", size: 124)).tracking(-3.5)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 64)
                SamplePanel(tools: SampleData.lineup, scale: Self.panelScale)
                    .padding(.bottom, 60)
                Text("Claude · Codex · Gemini · Cursor …")
                    .font(.custom("Pretendard-SemiBold", size: 36))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.bottom, 14)
                Text("무료 · macOS · Windows")
                    .font(.custom("Pretendard-SemiBold", size: 36))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .foregroundStyle(.white)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }

    private var title: AttributedString {
        var text = AttributedString("AI 한도,\n한눈에")
        if let range = text.range(of: "한눈에") { text[range].foregroundColor = Theme.accent }
        return text
    }
}
