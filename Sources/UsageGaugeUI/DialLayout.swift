import SwiftUI
import UsageGaugeCore

/// Cards in rows of two: a dial for the short window beside its reset time and a bar for the long one.
struct DialLayout: View {
    static let cardsPerRow = 2

    let providers: [ProviderUsage]
    let now: Date
    let frozenAt: TimeInterval?

    var body: some View {
        ProviderGrid(providers: providers, columns: Self.cardsPerRow) { index, usage, _ in
            ProviderCard(usage: usage, index: index, now: now, frozenAt: frozenAt)
        }
    }
}
