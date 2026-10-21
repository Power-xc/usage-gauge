import SwiftUI
import UsageGaugeUI

/// Near-black stage with glossy black spheres and chrome rings drifting slowly, so the frosted
/// glass in front has shapes to blur.
struct Backdrop: View {
    let time: Double
    /// Objects are placed round a panel centred at this point (unit coordinates of the canvas).
    var focus = UnitPoint(x: 0.5, y: 0.47)
    var showsObjects = true

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let u = min(w, h)
            let cx = w * focus.x
            let cy = h * focus.y
            let drift = time / 12 * 2 * .pi
            ZStack {
                RadialGradient(colors: [Color(white: 0.11), Color(white: 0.035)], center: UnitPoint(x: 0.5, y: 0.35),
                               startRadius: 0, endRadius: max(w, h) * 0.75)
                if showsObjects {
                    ChromeRing(thickness: u * 0.06)
                        .frame(width: u * 0.46, height: u * 0.46)
                        .rotation3DEffect(.degrees(58), axis: (x: 1, y: 0.2, z: 0))
                        .rotationEffect(.degrees(-16 + 5 * sin(drift)))
                        .position(x: cx + u * 0.2, y: cy + u * (0.21 + 0.01 * cos(drift)))
                    ChromeRing(thickness: u * 0.04)
                        .frame(width: u * 0.22, height: u * 0.22)
                        .rotation3DEffect(.degrees(50), axis: (x: 0.4, y: 1, z: 0))
                        .position(x: cx - u * (0.22 + 0.01 * sin(drift)), y: cy - u * 0.16)
                    GlossySphere().frame(width: u * 0.24)
                        .position(x: cx - u * 0.22, y: cy + u * (0.15 + 0.012 * sin(drift * 0.8)))
                    GlossySphere().frame(width: u * 0.14)
                        .position(x: cx + u * 0.19, y: cy - u * (0.19 + 0.01 * cos(drift)))
                    GlossySphere().frame(width: u * 0.05).position(x: cx + u * 0.33, y: cy - u * 0.02)
                }
            }
        }
    }
}

/// Black glass ball: a hard specular spot, a soft fill and a thin rim of light.
private struct GlossySphere: View {
    var body: some View {
        Circle()
            .fill(RadialGradient(stops: [
                .init(color: .white.opacity(0.85), location: 0),
                .init(color: Color(white: 0.35), location: 0.08),
                .init(color: Color(white: 0.09), location: 0.45),
                .init(color: Color(white: 0.02), location: 1),
            ], center: UnitPoint(x: 0.32, y: 0.28), startRadius: 0, endRadius: 120))
            .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.05), .white.opacity(0.45)],
                                                          startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
            .aspectRatio(1, contentMode: .fit)
    }
}

/// Polished ring: alternating bright and dark reflections round the tube.
private struct ChromeRing: View {
    let thickness: CGFloat

    var body: some View {
        Circle()
            .strokeBorder(AngularGradient(colors: [
                Color(white: 0.9), Color(white: 0.18), Color(white: 0.55), Color(white: 0.05),
                Color(white: 0.75), Color(white: 0.12), Color(white: 0.9),
            ], center: .center), lineWidth: thickness)
            .overlay(Circle().strokeBorder(LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.55)],
                                                          startPoint: .top, endPoint: .bottom), lineWidth: thickness))
    }
}

/// Off-screen stand-in for system glass: the backdrop behind the panel, frosted and smoked,
/// under a crisp slab edge. `scene` is the full canvas the backdrop was drawn at.
struct RenderedGlass: ViewModifier {
    static let space = "scene"

    let backdrop: Backdrop
    let scene: CGSize

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.panelCornerRadius, style: .continuous)
        content
            .background(shape.fill(Theme.smoke.opacity(0.46)))
            .background(GeometryReader { geo in
                let frame = geo.frame(in: .named(Self.space))
                backdrop
                    .frame(width: scene.width, height: scene.height)
                    .offset(x: -frame.minX, y: -frame.minY)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .blur(radius: 26)
            }
            .clipShape(shape))
            .overlay(GlassSlabEdge(shape: shape))
            .shadow(color: .black.opacity(0.6), radius: 40, y: 20)
    }
}
