// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "usage-gauge",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "usage-gauge", targets: ["UsageGauge"]),
    ],
    targets: [
        .target(name: "UsageGaugeCore"),
        .target(name: "UsageGaugeUI", dependencies: ["UsageGaugeCore"]),
        .executableTarget(name: "UsageGauge", dependencies: ["UsageGaugeCore", "UsageGaugeUI"]),
        // Renders README and promo frames from the real views with sample data.
        .executableTarget(name: "PromoRenderer", dependencies: ["UsageGaugeCore", "UsageGaugeUI"]),
        // Runs without XCTest so the checks work on Command Line Tools-only machines as well as CI.
        .executableTarget(name: "CoreChecks", dependencies: ["UsageGaugeCore"]),
    ]
)
