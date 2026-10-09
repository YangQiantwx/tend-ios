import SwiftUI
import UserNotifications

@main
struct TendApp: App {
    @State private var store: AppStore?
    @State private var startupError: String?
    init() {
        TendTheme.configureTabTypography()
        // Install before the asynchronous store load and before any view subscribes.
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let store {
                    RootView().environment(store)
                } else if let startupError {
                    ContentUnavailableView {
                        Label("Let's try that again", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Tend couldn't open its local study data. Your existing file has been preserved.\n\n\(startupError)")
                    } actions: { Button("Retry", action: load).buttonStyle(PrimaryButtonStyle()).padding() }
                } else {
                    ProgressView("Opening Tend…").frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .tendScreen().tint(TendTheme.forest)
            .task { if store == nil { load() } }
        }
    }

    private func load() {
        do {
            guard let configurationURL = Bundle.main.url(forResource: "study-config", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let configuration = try StudyConfiguration.load(from: configurationURL)
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                        appropriateFor: nil, create: true).appendingPathComponent("Tend")
            let mode = AppDataMode.current
            let directory = mode.directory(in: root)
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if mode.shouldReset(arguments: arguments), FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
            if mode == .uiTesting {
                try UITestScenario.prepare(directory: directory, configuration: configuration,
                                           arguments: arguments)
            } else if mode == .demo {
                try DemoScenario.prepare(directory: directory, configuration: configuration)
            }
            #endif
            store = try AppStore(configuration: configuration, directory: directory, dataMode: mode)
            startupError = nil
        } catch { startupError = error.localizedDescription }
    }
}
