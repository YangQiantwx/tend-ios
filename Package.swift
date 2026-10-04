// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TendCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "TendCore", targets: ["TendCore"])],
    targets: [
        .target(name: "TendCore", path: "Tend",
            exclude: ["Design", "Features", "Resources", "Info.plist", "App/RootView.swift",
                      "App/TendApp.swift", "App/UITestScenario.swift", "Services/PracticeNarrationPlayer.swift"],
            sources: ["Core", "App/AppStore.swift", "App/AppStore+Sessions.swift",
                      "App/AppStore+Support.swift", "App/CheckInDraft.swift", "Services/ReminderService.swift"]),
        .testTarget(name: "TendCoreTests", dependencies: ["TendCore"], path: "Tests/TendCoreTests")
    ]
)
