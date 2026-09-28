import SwiftUI

struct FitbitConnectionView: View {
    @Environment(AppStore.self) private var store
    @State private var showingDemoExplanation = false

    private var connection: FitbitDemoConnection? { store.data.fitbitDemoConnection }
    private var connected: Bool { connection?.isConnected == true }
    private var samples: [WearableDay] {
        store.data.wearableDays.filter { $0.source == "synthetic_demo" }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                Label(connected ? "Demo connection active" : "Demo disconnected", systemImage: "applewatch")
                    .font(.headline).foregroundStyle(TendTheme.forest)
                    .accessibilityIdentifier("fitbit.status")
                Text("Try the connection flow with sample data. No real Fitbit account or device is connected.")
                    .foregroundStyle(TendTheme.secondary)
                if connected {
                    Button("Sync sample data") { _ = store.syncFitbitDemo() }
                        .accessibilityIdentifier("fitbit.sync")
                    Button("Disconnect demo", role: .destructive) { _ = store.disconnectFitbitDemo() }
                        .accessibilityIdentifier("fitbit.disconnect")
                } else {
                    Button("Connect demo") { showingDemoExplanation = true }
                        .accessibilityIdentifier("fitbit.connect")
                }
            } footer: {
                Text("Fitbit data does not choose practices. This demo does not collect live readings.")
            }
            if let lastSync = connection?.lastSyncedAt {
                Section("Last sample sync") {
                    LabeledContent("Updated", value: lastSync.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Source", value: "Simulated data")
                    LabeledContent("Days", value: "\(samples.count)")
                }
            }
            if !samples.isEmpty {
                Section {
                    ForEach(samples) { sample in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(sample.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.headline)
                            LabeledContent("Steps", value: sample.steps.map { $0.formatted() } ?? "Not available")
                            LabeledContent("Active minutes", value: sample.activeMinutes.map(String.init) ?? "Not available")
                            LabeledContent("Sleep", value: sample.sleepHours.map { String(format: "%.1f hours", $0) } ?? "Not available")
                            LabeledContent("Resting heart rate", value: sample.restingHeartRate.map { "\($0) bpm" } ?? "Not available")
                        }
                        .font(.subheadline)
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Simulated readings")
                } footer: {
                    Text("Missing sample values remain unavailable. Disconnecting keeps these clearly labeled samples in your local history.")
                }
                .accessibilityIdentifier("fitbit.samples")
            }
        }
        .scrollContentBackground(.hidden)
        .tendScreen()
        .tint(TendTheme.forest)
        .navigationTitle("Fitbit demo")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Connect the demo?", isPresented: $showingDemoExplanation) {
            Button("Cancel", role: .cancel) { }
            Button("Use demo connection") { _ = store.connectFitbitDemo() }
        } message: {
            Text("This enables sample sync on this device. It does not sign in to Fitbit, request credentials, or access a wearable.")
        }
    }
}
