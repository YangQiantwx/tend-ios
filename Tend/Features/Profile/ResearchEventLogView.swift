import SwiftUI

struct ResearchEventLogView: View {
    @Environment(AppStore.self) private var store
    private var events: [StudyEvent] { store.data.events.sorted { $0.timestamp > $1.timestamp } }
    var body: some View {
        List {
            if events.isEmpty {
                EmptyMoment(symbol: "text.book.closed", title: "No events yet",
                            message: "Check-ins and practice interactions will create local event records.")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(events) { event in
                    NavigationLink { StudyEventDetailView(event: event) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.subheadline.weight(.medium))
                            Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
                                .font(.caption).foregroundStyle(TendTheme.secondary)
                        }.padding(.vertical, 4)
                    }
                }
            }
        }.scrollContentBackground(.hidden).tendScreen()
            .navigationTitle("Event log").navigationBarTitleDisplayMode(.inline)
    }
}

private struct StudyEventDetailView: View {
    let event: StudyEvent
    var body: some View {
        List {
            Section("Event") {
                LabeledContent("Kind", value: event.kind)
                LabeledContent("Time", value: event.timestamp.formatted(date: .abbreviated, time: .standard))
                LabeledContent("Reference", value: event.referenceID ?? "None")
                Text(event.id.uuidString).font(.caption.monospaced()).textSelection(.enabled)
            }
            Section("Details") {
                if event.details.isEmpty { Text("No additional details").foregroundStyle(TendTheme.secondary) }
                ForEach(event.details.keys.sorted(), id: \.self) { key in
                    LabeledContent(key, value: event.details[key] ?? "")
                }
            }
        }.scrollContentBackground(.hidden).tendScreen()
            .navigationTitle("Event detail").navigationBarTitleDisplayMode(.inline)
    }
}
