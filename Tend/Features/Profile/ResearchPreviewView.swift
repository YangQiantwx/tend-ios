import SwiftUI

struct ResearchPreviewView: View {
    @Environment(AppStore.self) private var store
    @State private var export: URL?
    @State private var exportError: String?
    private var scheduled: Int { store.data.checkIns.filter { $0.origin == .scheduled }.count }
    private var onDemand: Int { store.data.checkIns.filter { $0.origin == .onDemand }.count }
    private var analysis: ResearchAnalysisSnapshot {
        .build(data: store.data, configuration: store.configuration)
    }
    private var lastSync: Date? { store.data.wearableDays.compactMap(\.syncedAt).max() }
    private var missingFields: Int {
        store.data.wearableDays.reduce(0) { result, day in
            result + [day.steps == nil, day.activeMinutes == nil, day.sleepHours == nil, day.restingHeartRate == nil].filter { $0 }.count
        }
    }

    var body: some View {
        List {
            Section("Participation") {
                LabeledContent("Scheduled EMA records", value: "\(scheduled)")
                LabeledContent("On-demand EMA records", value: "\(onDemand)")
                LabeledContent("Practices completed", value: "\(store.data.sessions.filter(\.completed).count)")
                LabeledContent("Practices ended early", value: "\(store.data.sessions.filter { !$0.completed }.count)")
                LabeledContent("Saved practices", value: "\(store.data.savedPracticeIDs.count)")
            }
            Section("Protocol update · September 2026") {
                ResearchPhaseCard(snapshot: analysis).padding(.vertical, 8)
                NavigationLink { ResearchProtocolView(snapshot: analysis) } label: {
                    Label("Study phases & observed labels", systemImage: "point.3.connected.trianglepath.dotted")
                }.accessibilityIdentifier("research.protocol")
            }
            Section("Wearable data quality") {
                LabeledContent("Connection", value: "No Fitbit connected")
                LabeledContent("Sample days", value: "\(store.data.wearableDays.count)")
                LabeledContent("Sample last sync", value: lastSync?.formatted(date: .abbreviated, time: .shortened) ?? "Not available")
                LabeledContent("Missing sample metrics", value: store.data.wearableDays.isEmpty ? "No samples" : "\(missingFields)")
                Text("Missing means unknown, not zero. Sample Fitbit data never affects practice suggestions.")
                    .font(.caption).foregroundStyle(TendTheme.secondary)
                if store.data.wearableDays.isEmpty {
                    Button("Load sample wearable data") {
                        if store.loadSampleWearables() { export = nil }
                    }.accessibilityIdentifier("research.loadSample")
                }
            }
            Section("Local records") {
                NavigationLink { ResearchEventLogView() } label: {
                    LabeledContent("Event log", value: "\(store.data.events.count)")
                }.accessibilityIdentifier("research.events")
                if let export {
                    ShareLink(item: export) {
                        Label("Share JSON export", systemImage: "square.and.arrow.up")
                    }.accessibilityIdentifier("research.share")
                    Button("Refresh export") { prepareExport() }
                } else {
                    Button { prepareExport() } label: { Label("Prepare JSON export", systemImage: "doc.badge.arrow.up") }
                        .accessibilityIdentifier("research.export")
                }
                if let exportError { Text(exportError).font(.caption).foregroundStyle(TendTheme.terracotta) }
            }
            Section("Configuration") {
                LabeledContent("Protocol source", value: store.configuration.protocolVersion ?? "Original prototype")
                LabeledContent("Rule version", value: store.configuration.ruleVersion)
                LabeledContent("Rule status", value: store.configuration.ruleStatus.replacingOccurrences(of: "_", with: " ").capitalized)
                LabeledContent("JSON schema", value: "\(store.data.schemaVersion)")
            }
        }
        .scrollContentBackground(.hidden).tendScreen().tint(TendTheme.forest)
        .navigationTitle("Study data & export").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("research.screen")
    }

    private func prepareExport() {
        do { export = try store.exportURL(); exportError = nil }
        catch { exportError = error.localizedDescription; export = nil }
    }
}
