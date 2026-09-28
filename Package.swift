// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TendCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "TendCore", targets: ["TendCore"])],
    targets: [
        .target(name: "TendCore", path: "Tend/Core"),
        .testTarget(name: "TendCoreTests", dependencies: ["TendCore"], path: "Tests/TendCoreTests")
    ]
)
