import SwiftUI
import UsageGaugeCore
import UsageGaugeUI

/// All twelve graph forms, three to a row in the order of the picker. Mono is the default and
/// carries most of the page; one row in iris and one in dot show the other styles on the same forms.
struct GraphsScene: View {
    private static let columns = 3
    private static let styles: [PanelStyle] = [.mono, .iris, .mono, .dot]

    var body: some View {
        Staged(margin: 48) {
            VStack(spacing: 44) {
                ForEach(0..<(PanelLayout.allCases.count / Self.columns), id: \.self) { row in
                    HStack(alignment: .top, spacing: 44) {
                        ForEach(0..<Self.columns, id: \.self) { column in cell(row * Self.columns + column, row: row) }
                    }
                }
            }
        }
    }

    private func cell(_ index: Int, row: Int) -> some View {
        let layout = PanelLayout.allCases[index]
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(String(format: "%02d", index + 1)).font(Theme.mono(13, .medium)).foregroundStyle(Theme.faintText)
                Text(layout.title).font(Theme.font(22, .semibold)).foregroundStyle(Theme.mutedText)
            }
            .padding(.leading, 4)
            SamplePanel(style: Self.styles[row], layout: layout)
        }
    }
}

/// The dial form in each of the three styles, named underneath.
struct StylesScene: View {
    var body: some View {
        Staged {
            HStack(alignment: .top, spacing: 56) {
                ForEach(PanelStyle.allCases, id: \.self) { style in
                    VStack(spacing: 22) {
                        SamplePanel(style: style)
                        Caption(title: style.title, size: 22)
                    }
                }
            }
        }
    }
}

/// Interaction in one composition: the 전체 tab with a hovered cell revealing its line, beside a
/// tool's detail page with its tab selected.
struct InteractionScene: View {
    var body: some View {
        Staged {
            HStack(alignment: .top, spacing: 56) {
                VStack(spacing: 22) {
                    SamplePanel(hovered: "codex")
                    Caption(title: "마우스를 올리면 초기화 시각", size: 22)
                }
                VStack(spacing: 22) {
                    SamplePanel(tool: "claude")
                    Caption(title: "탭을 누르면 도구별 상세", size: 22)
                }
            }
        }
    }
}

/// The panel at three sizes, bottoms aligned, with the factor underneath.
struct SizesScene: View {
    private static let scales = [0.8, 1.0, 1.4]

    var body: some View {
        Staged {
            HStack(alignment: .bottom, spacing: 56) {
                ForEach(Self.scales, id: \.self) { scale in
                    VStack(spacing: 22) {
                        SamplePanel(tools: Array(SampleData.tools.prefix(2)), scale: scale)
                        Caption(title: String(format: "%.1f×", scale), size: 22)
                    }
                }
            }
        }
    }
}

/// The menu bar strip with bars on, as it ships.
struct MenuBarScene: View {
    static let size = CGSize(width: 1280, height: 240)

    var body: some View {
        ZStack {
            Backdrop()
            MenuBarStrip(providers: Array(SampleData.tools.prefix(3)), width: 600)
                .scaleEffect(2)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }
}

/// GitHub social card: the panel beside the name and one line, with margins GitHub's crop leaves alone.
struct SocialPreviewScene: View {
    static let size = CGSize(width: 1280, height: 640)

    var body: some View {
        ZStack {
            Backdrop(watermarkSize: 12)
            HStack(spacing: 64) {
                SamplePanel(tools: Array(SampleData.tools.prefix(2)), style: .mono, scale: 1.3)
                VStack(alignment: .leading, spacing: 18) {
                    Text("usage-gauge").font(Theme.font(64, .bold))
                    Text("모든 AI의 남은 한도를,\n언제 바닥나는지까지")
                        .font(Theme.font(28, .medium))
                        .foregroundStyle(Theme.mutedText)
                        .lineSpacing(6)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }
}
