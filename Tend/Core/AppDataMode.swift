import Foundation

/// Separate local records and preferences for everyday use, demos, and UI tests.
enum AppDataMode: String, Sendable {
    case standard, demo, uiTesting

    static var current: Self {
        #if DEBUG
        from(arguments: ProcessInfo.processInfo.arguments)
        #else
        .standard
        #endif
    }

    static func from(arguments: [String]) -> Self {
        if arguments.contains("--uitesting") { return .uiTesting }
        if arguments.contains("--demo") { return .demo }
        return .standard
    }

    var allowsSystemNotifications: Bool { self == .standard }

    func directory(in root: URL) -> URL {
        switch self {
        case .standard: root
        case .demo: root.appendingPathComponent("Demo", isDirectory: true)
        case .uiTesting: root.appendingPathComponent("UITests", isDirectory: true)
        }
    }

    func preferenceKey(_ key: String) -> String {
        self == .standard ? key : "\(key).\(rawValue)"
    }

    func shouldReset(arguments: [String]) -> Bool {
        switch self {
        case .standard: false
        case .demo: arguments.contains("--reset-demo-data")
        case .uiTesting: arguments.contains("--reset-test-data")
        }
    }
}
