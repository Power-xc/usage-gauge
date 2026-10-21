/// How urgent a remaining allowance is. Drives the gauge colour.
public enum UsageLevel: Equatable, Sendable {
    case comfortable
    case low
    case critical

    public static let lowThreshold = 30.0
    public static let criticalThreshold = 10.0

    public init(remainingPercent: Double) {
        if remainingPercent <= Self.criticalThreshold {
            self = .critical
        } else if remainingPercent <= Self.lowThreshold {
            self = .low
        } else {
            self = .comfortable
        }
    }
}
