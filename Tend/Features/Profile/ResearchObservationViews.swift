import SwiftUI

struct ResearchLabelHistoryView: View {
    let snapshot: ResearchAnalysisSnapshot
    @Environment(AppStore.self) private var store
    @State private var knownOnly = false
    private var labels: [ResearchDistressLabel] {
        snapshot.labels.reversed().filter { !knownOnly || $0.median != nil }
    }

    var body: some View {
        List {
            Section {
                Toggle("Only labels with a threshold", isOn: $knownOnly)
                    .tint(TendTheme.forest).accessibilityIdentifier("research.knownOnly")
                Text("Observed responses · no predictions").font(.caption).foregroundStyle(TendTheme.secondary)
            }
            if labels.isEmpty {
                ContentUnavailableView("No labels to show", systemImage: "chart.dots.scatter",
                    description: Text(knownOnly ? "Turn off the filter to see records still building their history." : "Saved scheduled check-ins will appear here."))
            }
            ForEach(labels) { label in
                Section {
                    HStack {
                        Text(label.completedAt.formatted(date: .abbreviated, time: .shortened))
                        Spacer()
                        Text("\(label.distress) / 5").monospacedDigit()
                    }.font(.subheadline.weight(.medium))
                    LabeledContent("Observed label", value: label.status.title)
                    LabeledContent("Prior seven-day median", value: label.median.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "Unavailable")
                    LabeledContent("Earlier observations", value: "\(label.historySampleCount)")
                    if let record = store.data.checkIns.first(where: { $0.id == label.recordID }) {
                        NavigationLink("View original check-in") { CheckInRecordView(record: record) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).tendScreen()
        .navigationTitle("EMA labels").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("research.labelHistory")
    }
}

struct ResearchTransitionHistoryView: View {
    let snapshot: ResearchAnalysisSnapshot
    @Environment(AppStore.self) private var store
    @State private var evaluableOnly = false
    private var transitions: [ResearchTransition] {
        snapshot.transitions.reversed().filter { !evaluableOnly || $0.status.transitionOccurred != nil }
    }

    var body: some View {
        List {
            Section {
                Toggle("Only evaluable transitions", isOn: $evaluableOnly).tint(TendTheme.forest)
                    .accessibilityIdentifier("research.evaluableOnly")
                Text("Adjacent scheduled slots within a day. No missing middle slot is skipped.")
                    .font(.caption).foregroundStyle(TendTheme.secondary)
            }
            if transitions.isEmpty {
                ContentUnavailableView("No transitions to show", systemImage: "arrow.right",
                    description: Text("Observed endpoints and a seven-day history are needed for an evaluable transition."))
            }
            ForEach(transitions) { transition in
                Section {
                    Text(transition.currentScheduledAt.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.headline)
                    LabeledContent("Planned slots", value: "\(time(transition.currentScheduledAt)) → \(time(transition.nextScheduledAt))")
                    LabeledContent("Status", value: transition.status.title)
                    if let reference = transition.decisionReference, let median = reference.median {
                        LabeledContent("Decision-time median", value: median.formatted(.number.precision(.fractionLength(0...1))))
                        Text("The same historical threshold is used for both responses.")
                            .font(.caption).foregroundStyle(TendTheme.secondary)
                    }
                    if let seconds = transition.observedIntervalSeconds {
                        LabeledContent("Observed interval", value: String(format: "%.1f hours", seconds / 3600))
                    }
                    recordLink("View current response", id: transition.currentRecordID)
                    recordLink("View next response", id: transition.nextRecordID)
                }
            }
        }
        .scrollContentBackground(.hidden).tendScreen()
        .navigationTitle("Same-day transitions").navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func recordLink(_ title: String, id: UUID?) -> some View {
        if let record = store.data.checkIns.first(where: { $0.id == id }) {
            NavigationLink(title) { CheckInRecordView(record: record) }
        }
    }
    private func time(_ date: Date) -> String { date.formatted(.dateTime.hour().minute()) }
}

private extension ResearchLabelStatus {
    var title: String {
        switch self {
        case .insufficientHistory: "Building seven-day history"
        case .noHistorySamples: "No earlier observations"
        case .notElevated: "Not elevated"
        case .elevated: "Elevated"
        }
    }
}

private extension ResearchTransitionStatus {
    var title: String {
        switch self {
        case .pending: "Upcoming opportunity"
        case .missingCurrent: "Current response missing"
        case .missingNext: "Next response missing"
        case .missingBoth: "Both responses missing"
        case .unknownLabel: "History unavailable"
        case .nonChronological: "Responses out of order"
        case .currentAlreadyElevated: "Current response already elevated"
        case .elevatedTransition: "Transition to elevated"
        case .noElevation: "No transition to elevated"
        }
    }
}
