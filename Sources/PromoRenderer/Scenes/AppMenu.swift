import SwiftUI
import UsageGaugeUI

/// When the app menu is open and which rows the pointer lights, in scene seconds.
struct AppMenuPlan {
    let opensAt: Double
    let closesAt: Double
    /// Rows lit from each time on; nil lights nothing.
    let lit: [(at: Double, row: AppMenu.Row?)]
    /// When the graph submenu opens beside its row, and the graph it marks as current.
    let submenuAt: Double
    let current: PanelLayout
    /// The submenu row lit from each time on.
    let submenuLit: [(at: Double, layout: PanelLayout?)]
}

/// The app's menu as macOS draws it in dark mode, opened from the menu bar item: the items,
/// headers and checkmarks of `AppDelegate.buildMenu`, with the graph submenu beside its row.
struct AppMenu: View {
    enum Row: Equatable {
        case toggle, refresh, graph, style(PanelStyle), opacity, adaptive, size, bars, login, quit
    }

    private enum Item {
        case action(String, Row, shortcut: String? = nil)
        case check(String, Row, isOn: Bool)
        case submenu(String, Row)
        case header(String)
        case slider(Double)
        case separator
    }

    static let width: CGFloat = 248
    static let submenuWidth: CGFloat = 132
    private static let rowHeight: CGFloat = 22
    private static let sliderHeight: CGFloat = 30
    private static let separatorHeight: CGFloat = 11
    private static let inset: CGFloat = 5
    private static let highlight = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)

    private static let items: [Item] = [
        .action("게이지 켜기/끄기 (⌥⌘U)", .toggle),
        .action("지금 새로고침", .refresh),
        .separator,
        .submenu("그래프", .graph),
        .separator,
        .header("스타일"),
    ] + PanelStyle.allCases.map { .check($0.title, .style($0), isOn: $0 == .mono) } + [
        .separator,
        .header("게이지 투명도"),
        .slider(1),
        .check("배경에 맞춰 유리 진하기 조절", .adaptive, isOn: true),
        .separator,
        .header("게이지 크기"),
        .slider(0.33),
        .separator,
        .check("메뉴바에 막대 표시", .bars, isOn: true),
        .separator,
        .check("로그인할 때 켜기", .login, isOn: true),
        .action("종료", .quit, shortcut: "⌘Q"),
    ]

    let plan: AppMenuPlan
    let time: Double
    /// Top-left of the menu, in the stage's points.
    let origin: CGPoint

    /// Centre of a row relative to the menu's origin, where the pointer goes to light it.
    static func rowCenter(_ row: Row) -> CGPoint {
        var y = inset
        for item in items {
            if Self.row(of: item) == row { return CGPoint(x: 70, y: y + height(of: item) / 2) }
            y += height(of: item)
        }
        return CGPoint(x: 70, y: y)
    }

    private static func row(of item: Item) -> Row? {
        switch item {
        case let .action(_, row, _), let .check(_, row, _), let .submenu(_, row): row
        default: nil
        }
    }

    /// Centre of a graph's row in the submenu, relative to the menu's origin.
    static func submenuCenter(_ layout: PanelLayout) -> CGPoint {
        let index = CGFloat(PanelLayout.allCases.firstIndex(of: layout) ?? 0)
        return CGPoint(x: width + 4 + 48, y: rowCenter(.graph).y - rowHeight / 2 + rowHeight * (index + 0.5))
    }

    private static func height(of item: Item) -> CGFloat {
        switch item {
        case .separator: separatorHeight
        case .slider: sliderHeight
        default: rowHeight
        }
    }

    var body: some View {
        let shown = Motion.progress(time, from: plan.opensAt, to: plan.opensAt + 0.1)
            * (1 - Motion.progress(time, from: plan.closesAt, to: plan.closesAt + 0.12))
        let submenu = Motion.progress(time, from: plan.submenuAt, to: plan.submenuAt + 0.08)
        ZStack(alignment: .topLeading) {
            menu
            graphs
                .offset(x: Self.width + 4, y: Self.rowCenter(.graph).y - Self.rowHeight / 2 - Self.inset)
                .opacity(submenu)
        }
        .offset(x: origin.x, y: origin.y)
        .opacity(shown)
    }

    private var menu: some View {
        let lit = plan.lit.last { $0.at <= time }?.row
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.items.enumerated()), id: \.offset) { _, item in row(item, lit: lit) }
        }
        .padding(.vertical, Self.inset)
        .frame(width: Self.width)
        .modifier(MenuSurface())
    }

    private var graphs: some View {
        let lit = plan.submenuLit.last { $0.at <= time }?.layout
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(PanelLayout.allCases, id: \.self) { layout in
                line(layout.title, isOn: layout == plan.current, isLit: layout == lit)
            }
        }
        .padding(.vertical, Self.inset)
        .frame(width: Self.submenuWidth)
        .modifier(MenuSurface())
    }

    @ViewBuilder
    private func row(_ item: Item, lit: Row?) -> some View {
        switch item {
        case let .action(title, row, shortcut): line(title, isLit: row == lit, shortcut: shortcut)
        case let .check(title, row, isOn): line(title, isOn: isOn, isLit: row == lit)
        case let .submenu(title, row): line(title, isLit: row == lit, hasSubmenu: true)
        case let .header(title):
            Text(title).font(Theme.font(11, .semibold)).foregroundStyle(.white.opacity(0.48))
                .frame(height: Self.rowHeight, alignment: .bottom)
                .padding(.leading, 14)
        case let .slider(value): MenuSlider(value: value).frame(height: Self.sliderHeight)
        case .separator:
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
                .padding(.horizontal, 10).frame(height: Self.separatorHeight)
        }
    }

    private func line(_ title: String, isOn: Bool = false, isLit: Bool, shortcut: String? = nil,
                      hasSubmenu: Bool = false) -> some View {
        HStack(spacing: 0) {
            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                .opacity(isOn ? 1 : 0)
                .frame(width: 18)
            Text(title).font(Theme.font(13)).lineLimit(1)
            Spacer(minLength: 12)
            if let shortcut { Text(shortcut).font(Theme.font(13)).foregroundStyle(.white.opacity(isLit ? 1 : 0.45)) }
            if hasSubmenu {
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(isLit ? 1 : 0.6))
            }
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .frame(height: Self.rowHeight)
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Self.highlight.opacity(isLit ? 1 : 0))
            .padding(.horizontal, Self.inset))
    }
}

/// The menu's dark, nearly opaque sheet with a hairline rim, as macOS draws menus.
private struct MenuSurface: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        content
            .background(shape.fill(Color(white: 0.15).opacity(0.97)))
            .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
    }
}

/// A menu's live slider: an accent fill up to a white knob.
private struct MenuSlider: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            let track = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2)).frame(height: 4)
                Capsule().fill(Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255))
                    .frame(width: max(4, track * value), height: 4)
                Circle().fill(.white).frame(width: 15, height: 15)
                    .shadow(color: .black.opacity(0.3), radius: 1.5, y: 0.5)
                    .offset(x: (track - 15) * value)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 22)
    }
}
