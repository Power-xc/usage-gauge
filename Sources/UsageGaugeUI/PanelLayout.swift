import SwiftUI

/// How the panel arranges the tools. Independent of the style: every layout shows the same numbers
/// and draws them in whichever style is chosen.
public enum PanelLayout: String, CaseIterable, Sendable {
    /// Cards with a dial for the short window and a bar for the long one.
    case dial
    /// A compact list: both windows of a tool as labelled bars.
    case bars
    /// A column chart comparing every tool's two windows.
    case columns
    /// The smallest form: the short-window figure and one line for the long window.
    case figures
    /// Concentric rings, one per tool, with the lowest share in the middle and a legend beside.
    case orbit
    /// A capsule per tool filled to the short window's share, the long window under it.
    case capsule
    /// A line chart of each tool's short window over its period, from the recorded history.
    case trend

    public var title: String {
        switch self {
        case .dial: "다이얼"
        case .bars: "바"
        case .columns: "막대 그래프"
        case .figures: "숫자"
        case .orbit: "궤도"
        case .capsule: "캡슐"
        case .trend: "추이"
        }
    }

    /// Width of the content inside the panel padding; the layouts all fill it so switching between
    /// them keeps the panel's width.
    static let contentWidth: CGFloat = 472
    static let blockSpacing: CGFloat = 10
    static let cellSpacing: CGFloat = 24
}
