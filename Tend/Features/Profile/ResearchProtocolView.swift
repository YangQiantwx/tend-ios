import SwiftUI

struct ResearchPhaseCard: View {
    let snapshot: ResearchAnalysisSnapshot
    @ScaledMetric(relativeTo: .title2) private var titleSize = 26
    private var week: Int? { snapshot.studyDay.map { ($0 - 1) / 7 + 1 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.phase.title).font(TendTheme.display(titleSize))
                Spacer(minLength: 8)
                if let day = snapshot.studyDay {
                    Text("Day \(day)").font(.subheadline.monospacedDigit())
                }
            }
            HStack(spacing: 6) {
                ForEach(1...8, id: \.self) { value in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(week == value ? TendTheme.forest : TendTheme.sage)
                            .frame(height: 12)
                        Text("\(value)").font(.caption.monospacedDigit())
                    }.frame(maxWidth: .infinity)
                }
            }.accessibilityElement(children: .ignore)
                .accessibilityLabel(week.map { "Week \($0) of 8" } ?? snapshot.phase.title)
            Text("Week 1 · History\nWeeks 2–6 · Development   /   Weeks 7–8 · Held out")
                .font(.caption).foregroundStyle(TendTheme.secondary).lineSpacing(4)
        }
        .foregroundStyle(TendTheme.ink)
        .accessibilityIdentifier("research.phase")
    }
}

struct ResearchProtocolView: View {
    let snapshot: ResearchAnalysisSnapshot
    var body: some View {
        List {
            Section { ResearchPhaseCard(snapshot: snapshot).padding(.vertical, 8) }
            Section("Observed data") {
                NavigationLink { ResearchLabelHistoryView(snapshot: snapshot) } label: {
                    LabeledContent("EMA labels", value: "\(snapshot.labels.count)")
                }.accessibilityIdentifier("research.labels")
                LabeledContent("Labels with a historical threshold", value: "\(snapshot.counts.knownLabels)")
                LabeledContent("History unavailable", value: "\(snapshot.labels.count - snapshot.counts.knownLabels)")
                NavigationLink { ResearchTransitionHistoryView(snapshot: snapshot) } label: {
                    LabeledContent("Same-day transitions", value: "\(snapshot.transitions.count)")
                }.accessibilityIdentifier("research.transitions")
                LabeledContent("Evaluable transitions", value: "\(snapshot.counts.evaluableTransitions)")
                LabeledContent("Missing endpoint records", value: "\(snapshot.counts.missingTransitions)")
                LabeledContent("Upcoming opportunities", value: "\(snapshot.counts.pendingTransitions)")
            }
            Section {
                DisclosureGroup("How labels work") {
                    Text("Elevated means above the median of the preceding seven days of scheduled EMA. The first seven days build history.")
                    Text("A transition goes from non-elevated to elevated in the next same-day slot. Missing answers stay unknown.")
                    Text("History ready: \(snapshot.historyReadyAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline).foregroundStyle(TendTheme.secondary)
                }
            }
            Section("Analysis schedule") {
                Label("Demonstration schedule", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                Text(snapshot.sourceConflict).font(.subheadline).foregroundStyle(TendTheme.secondary)
                Text("Analysis settings are documented in the project README.")
                    .font(.caption).foregroundStyle(TendTheme.secondary)
            }
            Section("Analysis conventions") {
                ForEach(snapshot.limitations, id: \.self) { Text($0).font(.footnote) }
                LabeledContent("Time zone", value: snapshot.timezoneID)
                LabeledContent("Excluded records", value: "\(snapshot.excludedRecords.count)")
                Text("Thresholds, source IDs, exclusions and conventions are included in the JSON export. This is an inspection snapshot from \(snapshot.generatedAt.formatted(date: .abbreviated, time: .shortened)).")
                    .font(.caption).foregroundStyle(TendTheme.secondary)
            }
        }
        .scrollContentBackground(.hidden).tendScreen()
        .navigationTitle("Study phases & labels").navigationBarTitleDisplayMode(.inline)
    }
}
