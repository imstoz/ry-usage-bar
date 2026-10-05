// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "RYUsageBar", platforms: [.macOS(.v13)], products: [.executable(name: "RYUsageBar", targets: ["UsageBar"])], targets: [.target(name: "UsageCore"), .executableTarget(name: "UsageBar", dependencies: ["UsageCore"]), .testTarget(name: "UsageCoreTests", dependencies: ["UsageCore"])])
