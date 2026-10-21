import SwiftUI

/// Where a node's tag sits: on the side the field has room for, shifted up or down until it clears
/// the other tags and markers.
struct TagPlacement: Equatable {
    enum Side { case left, right }

    var side: Side
    /// Vertical shift of the tag's centre from its node, in points.
    var offset: CGFloat
}

/// Sizes of the constellation's node marks and the placement of their tags.
enum TagLayout {
    static let markerSize: CGFloat = 7
    /// Length of the short line that ties a tag to its marker.
    static let leader: CGFloat = 9
    static let height: CGFloat = 17
    /// Free space kept between two tags, and around a marker.
    private static let gap: CGFloat = 3
    private static let markerClearance = markerSize / 2 + gap

    /// Distance from a node's centre to the near edge of its tag.
    static let reach = markerSize / 2 + leader

    /// Side and vertical shift for every tag. `points` are the node centres and `widths` the tag
    /// widths, both in the field's coordinates; tags stay inside `bounds` where the tools allow.
    /// A tag takes the side that needs the smaller shift, the right one when they tie.
    static func place(points: [CGPoint], widths: [CGFloat], in bounds: CGRect) -> [TagPlacement] {
        let order = points.indices.sorted { points[$0].y < points[$1].y }
        let limit = bounds.maxY - height / 2
        let forward = settle(order, points: points, widths: widths, bounds: bounds, direction: 1, limit: limit)
        let lowest = zip(points, forward).map { $0.y + $1.offset }.max() ?? 0
        return lowest > limit ? settle(order.reversed(), points: points, widths: widths, bounds: bounds, direction: -1, limit: limit)
                              : forward
    }

    /// Places the tags in `order`, each pushed past whatever it overlaps in `direction` (1 = down).
    private static func settle(_ order: [Int], points: [CGPoint], widths: [CGFloat], bounds: CGRect,
                               direction: CGFloat, limit: CGFloat) -> [TagPlacement] {
        var placements = points.map { _ in TagPlacement(side: .right, offset: 0) }
        var placed: [(span: ClosedRange<CGFloat>, range: ClosedRange<CGFloat>)] = []
        let markers = points.map { point in
            (span: (point.x - markerClearance)...(point.x + markerClearance),
             range: (point.y - markerClearance)...(point.y + markerClearance))
        }
        let clearance = gap + height / 2 + 1
        for index in order {
            let point = points[index]
            let candidates = [TagPlacement.Side.right, .left].filter { side in
                side == .right ? point.x + reach + widths[index] <= bounds.maxX : point.x - reach - widths[index] >= bounds.minX
            }
            let best = (candidates.isEmpty ? [.left] : candidates).map { side -> (side: TagPlacement.Side, center: CGFloat) in
                let start = side == .right ? point.x + reach : point.x - reach - widths[index]
                let span = start...(start + widths[index])
                var center = min(point.y, limit)
                let obstacles = markers.indices.filter { $0 != index }.map { markers[$0] } + placed
                while let block = obstacles.first(where: { overlaps($0, span: span, center: center) }) {
                    center = direction > 0 ? block.range.upperBound + clearance : block.range.lowerBound - clearance
                }
                return (side, center)
            }.min { abs($0.center - point.y) < abs($1.center - point.y) }
            guard let best else { continue }
            let start = best.side == .right ? point.x + reach : point.x - reach - widths[index]
            placed.append((span: start...(start + widths[index]), range: (best.center - height / 2)...(best.center + height / 2)))
            placements[index] = TagPlacement(side: best.side, offset: best.center - point.y)
        }
        return placements
    }

    private static func overlaps(_ obstacle: (span: ClosedRange<CGFloat>, range: ClosedRange<CGFloat>),
                                 span: ClosedRange<CGFloat>, center: CGFloat) -> Bool {
        obstacle.span.overlaps(span) && obstacle.range.overlaps((center - height / 2 - gap)...(center + height / 2 + gap))
    }
}
