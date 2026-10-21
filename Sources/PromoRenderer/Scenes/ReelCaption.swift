import SwiftUI
import UsageGaugeUI

/// One subtitle of the reel: a small chapter mark, a title of one or two lines with one phrase in
/// the accent colour, and a quieter line under it.
struct ReelLine {
    /// A chapter mark that follows the panel: the graph, the style, or the graph × style on show.
    enum Live { case graph, style, look }

    let start: Double
    let end: Double
    var mark: String?
    var live: Live?
    let title: String
    var accent: String?
    var detail: String?
}

/// The reel's subtitles, set in Pretendard (it falls back to the system face where it is not
/// installed). Lines rise into place one after another and leave together, so each subtitle
/// reads as one beat.
struct ReelCaption: View {
    static let titleSize: CGFloat = 80
    private static let detailSize: CGFloat = 36
    private static let markSize: CGFloat = 23
    private static let rise: CGFloat = 26
    private static let enter = 0.34
    private static let leave = 0.2
    private static let stagger = 0.07

    let line: ReelLine
    let time: Double

    var body: some View {
        let rows = line.title.components(separatedBy: "\n")
        let leaving = Motion.progress(time, from: line.end - Self.leave, to: line.end)
        VStack(spacing: 0) {
            if let mark = line.mark {
                Text(mark)
                    .font(Theme.mono(Self.markSize, .medium)).tracking(3)
                    .foregroundStyle(Theme.accent.opacity(0.9))
                    .modifier(Arrival(progress: arrival(0)))
                    .padding(.bottom, 26)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                Text(highlighted(row))
                    .font(.custom("Pretendard-ExtraBold", size: Self.titleSize))
                    .tracking(-1.6)
                    .modifier(Arrival(progress: arrival(index + 1)))
            }
            if let detail = line.detail {
                Text(detail)
                    .font(.custom("Pretendard-SemiBold", size: Self.detailSize))
                    .tracking(-0.4)
                    .foregroundStyle(.white.opacity(0.6))
                    .modifier(Arrival(progress: arrival(rows.count + 1)))
                    .padding(.top, 26)
            }
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .opacity(1 - leaving)
        .offset(y: -12 * leaving)
    }

    /// How far the n-th row has arrived, each a moment after the one above it.
    private func arrival(_ index: Int) -> Double {
        let start = line.start + Self.stagger * Double(index)
        return Motion.rise(time, from: start, to: start + Self.enter)
    }

    private func highlighted(_ row: String) -> AttributedString {
        var text = AttributedString(row)
        if let accent = line.accent, let range = text.range(of: accent) {
            text[range].foregroundColor = Theme.accent
        }
        return text
    }

    /// Rises a little and fades in as `progress` goes from 0 to 1.
    private struct Arrival: ViewModifier {
        let progress: Double

        func body(content: Content) -> some View {
            content.opacity(progress).offset(y: ReelCaption.rise * (1 - progress))
        }
    }
}
