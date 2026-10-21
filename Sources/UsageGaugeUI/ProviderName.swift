import SwiftUI
import UsageGaugeCore

/// The tool's name in the style's voice, always with its brand mark: a square (mono), "01"
/// numbering (dot) or a small dot (iris).
struct ProviderName: View {
    let usage: ProviderUsage
    /// Position in the panel, shown as "01", "02", … by the dot style.
    let index: Int
    let tint: Color

    @Environment(\.panelStyle) private var style

    var body: some View {
        switch style {
        case .iris:
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 6, height: 6)
                Text(usage.title).font(Theme.font(13, .semibold))
            }
        case .dot:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%02d", index + 1)).font(Theme.mono(9, .medium)).foregroundStyle(Theme.faintText)
                Text(usage.title.uppercased()).font(Theme.mono(11.5, .semibold)).tracking(0.6)
            }
        case .mono:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Rectangle().fill(tint).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                Text(usage.title.uppercased()).font(Theme.mono(11.5, .semibold)).tracking(0.6)
            }
        }
    }
}

/// The subscription plan in small caps beside a tool's name; nothing when the plan is unknown.
struct PlanTag: View {
    let plan: String?

    @Environment(\.panelStyle) private var style

    var body: some View {
        if let plan {
            Text(plan.uppercased())
                .font(Theme.label(TypeScale.micro, .semibold, style: style))
                .tracking(0.9)
                .foregroundStyle(Theme.faintText)
        }
    }
}

/// Name and plan on one line: what heads every cell wide enough for both.
struct ProviderTitle: View {
    let usage: ProviderUsage
    let index: Int
    let tint: Color
    /// Lets the plan give way to the reset and measuring times while the cell is hovered.
    var revealsTimes = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            ProviderName(usage: usage, index: index, tint: tint)
            if revealsTimes {
                RevealingCaption(usage: usage) { PlanTag(plan: usage.plan) }
            } else {
                PlanTag(plan: usage.plan)
            }
        }
    }
}
