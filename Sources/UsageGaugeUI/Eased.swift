import SwiftUI

/// Redraws its content for every in-between value while the value animates, so dials and bars
/// drawn on a Canvas ease to a new share instead of jumping.
struct Eased<Content: View>: View, Animatable {
    var value: Double
    let content: (Double) -> Content

    init(value: Double, @ViewBuilder content: @escaping (Double) -> Content) {
        self.value = value
        self.content = content
    }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View { content(value) }
}
