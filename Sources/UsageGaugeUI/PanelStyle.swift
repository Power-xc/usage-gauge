import SwiftUI

/// The panel's look. Every style shows the same numbers and keeps each tool's colour; only the
/// surface, dial, bar and type change.
public enum PanelStyle: String, CaseIterable, Sendable {
    /// Smoked glass with the iris dial and light-streak bars.
    case iris
    /// Matte charcoal card with dot-matrix figures, dotted rings and dot rows.
    case dot
    /// Black terminal grid with radial ticks, segmented bars and monospaced type.
    case mono

    public var title: String {
        switch self {
        case .iris: "홍채 · 글래스"
        case .dot: "도트 매트릭스"
        case .mono: "모노 터미널"
        }
    }

    /// Dot and mono set labels in monospaced type and count down tersely ("3h 50m").
    var isMonospaced: Bool { self != .iris }

    /// Soft glass and card corners; the terminal pane is nearly square.
    public var cornerRadius: CGFloat {
        self == .mono ? 8 : Theme.panelCornerRadius
    }
}

private struct PanelStyleKey: EnvironmentKey {
    static let defaultValue = PanelStyle.iris
}

extension EnvironmentValues {
    public var panelStyle: PanelStyle {
        get { self[PanelStyleKey.self] }
        set { self[PanelStyleKey.self] = newValue }
    }
}
