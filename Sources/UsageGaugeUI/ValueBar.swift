import SwiftUI

/// Flat track you grab and drag to set a value in a range (the panel's opacity or size); fill and
/// knob follow the pointer.
struct ValueBar: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    private let knobSize: CGFloat = 14
    private let trackHeight: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let span = range.upperBound - range.lowerBound
            let fraction = (value - range.lowerBound) / span
            let travel = max(1, geo.size.width - knobSize)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track).frame(height: trackHeight)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: knobSize / 2 + travel * fraction, height: trackHeight)
                Circle()
                    .fill(.white)
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: travel * fraction)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let picked = min(1, max(0, (drag.location.x - knobSize / 2) / travel))
                value = range.lowerBound + span * picked
            })
        }
    }
}
