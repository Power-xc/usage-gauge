import SwiftUI
import UsageGaugeCore

/// One chart for every tool: a field where a tool's short-window share runs left to right and its
/// long-window share bottom to top, each tool a node with a tag, linked into a constellation in
/// order of short-window share. Where the history reaches back, a faded trail shows where each
/// tool stood an hour ago.
struct ConstellationLayout: View {
    private static let maxTools = 8

    let providers: [ProviderUsage]
    let history: UsageHistory
    let now: Date

    @Environment(\.panelStyle) private var style

    var body: some View {
        VStack(spacing: 0) {
            if style == .mono { GridRule(isVertical: false) }
            ConstellationField(stars: Array(ConstellationStar.stars(of: providers, history: history, now: now).prefix(Self.maxTools)),
                               unavailable: providers.filter { !$0.isAvailable })
                .frame(width: ConstellationPlot.frame.width, height: ConstellationPlot.frame.height)
                .frame(width: PanelLayout.contentWidth)
                .padding(style == .mono ? Theme.panelPadding : 0)
        }
        .toolFocusScope()
    }
}

/// The nodes, lines and guides laid out from the stars' positions.
private struct ConstellationField: View {
    private static let motion = Animation.smooth(duration: 0.6)
    private static let footnoteWidth: CGFloat = 220

    let stars: [ConstellationStar]
    let unavailable: [ProviderUsage]

    @Environment(\.panelStyle) private var style
    @Environment(\.toolFocus) private var focus

    var body: some View {
        let points = stars.map { ConstellationPlot.point($0.position) }
        let pasts = stars.map { $0.before.map(ConstellationPlot.point) }
        let widths = stars.map { ConstellationNode.tagWidth(for: $0.usage, style: style) }
        let placements = TagLayout.place(points: points, widths: widths, in: CGRect(x: 0, y: 0, width: ConstellationPlot.width,
                                                                                    height: ConstellationPlot.height))
        ZStack(alignment: .topLeading) {
            ConstellationGuides()
            ConstellationLinks(lines: stars.map { .init(tint: Theme.brand(for: $0.id), hasTrail: $0.before != nil) },
                               points: points, pasts: pasts)
            ForEach(Array(stars.enumerated()), id: \.element.id) { index, star in
                node(star, point: points[index], tagWidth: widths[index], placement: placements[index])
            }
            footnote
        }
        .animation(Self.motion, value: AnimatableValues(points.flatMap { [$0.x, $0.y] }))
        .animation(Self.motion, value: placements)
        .frame(width: ConstellationPlot.frame.width, height: ConstellationPlot.frame.height, alignment: .topLeading)
    }

    private func node(_ star: ConstellationStar, point: CGPoint, tagWidth: CGFloat, placement: TagPlacement) -> some View {
        let size = ConstellationNode.size(tagWidth: tagWidth, placement: placement)
        let marker = ConstellationNode.markerOffset(tagWidth: tagWidth, placement: placement)
        return ConstellationNode(usage: star.usage, placement: placement, tagWidth: tagWidth)
            .frame(width: size.width, height: size.height)
            .toolMark(star.id)
            .offset(x: point.x - marker.x, y: point.y - marker.y)
            .opacity(star.usage.isAvailable ? 1 : 0.5)
    }

    /// Under the field: the tools that report nothing and so cannot be placed, or the focused
    /// tool's reset and measuring times while one is pointed at.
    private var footnote: some View {
        let shown = focus.tool.flatMap { id in stars.first { $0.id == id }?.usage }
        return ZStack(alignment: .leading) {
            if !unavailable.isEmpty || stars.isEmpty {
                Text("연결 안 됨 · " + unavailable.map { style == .iris ? $0.title : $0.title.uppercased() }.joined(separator: ", "))
                    .font(Theme.label(TypeScale.micro, .medium, style: style))
                    .foregroundStyle(Theme.faintText)
                    .opacity(shown == nil ? 1 : 0)
            }
            Text(shown.map { HoverDetail.line(for: $0) } ?? "")
                .font(Theme.figure(TypeScale.caption, .regular, style: style))
                .foregroundStyle(Theme.mutedText)
                .opacity(shown == nil ? 0 : 1)
        }
        .frame(width: Self.footnoteWidth, alignment: .leading)
        .position(x: ConstellationPlot.field.minX + Self.footnoteWidth / 2, y: ConstellationPlot.field.maxY + 14)
        .animation(ToolFocus.motion, value: focus.tool)
    }
}
