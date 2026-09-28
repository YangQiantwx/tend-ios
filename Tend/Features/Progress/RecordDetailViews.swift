import SwiftUI

struct CheckInRecordView: View {
    @Environment(AppStore.self) private var store
    let record: CheckInRecord
    var body: some View {
        List {
            Section {
                Label(record.origin == .scheduled ? "Scheduled check-in" : "On-demand check-in",
                      systemImage: record.origin == .scheduled ? "sun.max" : "heart")
                    .font(.headline).foregroundStyle(TendTheme.forest)
                LabeledContent("Completed", value: record.completedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Time zone", value: record.timezoneID)
            }
            Section("Your responses") {
                ForEach(JourneyRating.allCases) { rating in
                    response(rating, rating.value(in: record.answers))
                }
                LabeledContent("Available time", value: record.answers.availableTime.label)
            }
            Section {
                ForEach(record.recommendedPracticeIDs, id: \.self) { id in
                    if let practice = store.practice(id: id) {
                        if record.recommendationsAvailable(at: Date()) {
                            NavigationLink {
                                if record.recommendationsAvailable(at: Date()) {
                                    PracticeDetailView(practice: practice, checkInID: record.id)
                                } else {
                                    ExpiredRecommendationView()
                                }
                            } label: {
                                recommendationRow(practice)
                            }.accessibilityIdentifier("journey.recommendation.\(id)")
                        } else {
                            recommendationRow(practice)
                                .accessibilityElement(children: .combine)
                        }
                    } else {
                        Text("This previously suggested practice is no longer in the current library.")
                            .font(.subheadline).foregroundStyle(TendTheme.secondary)
                    }
                }
            } header: {
                Text("Suggested for this check-in")
            } footer: {
                Text("Demo options expire after one hour.")
            }
            Section {
                Text("Self-reported ratings, not a diagnosis.")
                    .font(.footnote).foregroundStyle(TendTheme.secondary)
            }
        }
        .scrollContentBackground(.hidden).tendScreen().navigationTitle("Your check-in")
        .navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("journey.checkInDetail")
    }
    private func recommendationRow(_ practice: Practice) -> some View {
        HStack(spacing: 14) {
            PracticeSymbol(symbol: practice.symbol, size: 26, color: TendTheme.forest)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 5) {
                Text(practice.title).font(.body.weight(.medium))
                Text("\(max(1, practice.durationSeconds / 60)) min · \(practice.category == .movement ? "Physical activity" : "Mindfulness")")
                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
        }.padding(.vertical, 8)
    }
    private func response(_ rating: JourneyRating, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(rating.label, value: "\(value) of 5")
            HStack(spacing: 5) {
                ForEach(1...5, id: \.self) { number in
                    Capsule().fill(number <= value ? TendTheme.forest : TendTheme.line).frame(height: 5)
                }
            }.accessibilityHidden(true)
        }.padding(.vertical, 4)
    }
}

struct PracticeSessionRecordView: View {
    @Environment(AppStore.self) private var store
    let session: PracticeSession
    @State private var showingFeedback = false
    @ScaledMetric(relativeTo: .title) private var titleSize = 28
    private var current: PracticeSession { store.data.sessions.first { $0.id == session.id } ?? session }
    private var practice: Practice? { store.practice(id: current.practiceID) }
    var body: some View {
        List {
            Section {
                Text(practice?.title ?? "Practice").font(TendTheme.display(titleSize))
                    .fixedSize(horizontal: false, vertical: true)
                LabeledContent("Status", value: current.completed ? "Completed" : "Ended early")
                LabeledContent("Date", value: current.endedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Time in practice", value: duration)
                LabeledContent("Recorded as", value: "Self-reported")
            }
            Section("Your optional feedback") {
                LabeledContent("Helpfulness", value: current.helpfulness.map { "\($0) of 5" } ?? "Not rated")
                if let after = current.postPracticeDistress,
                   let recordedAt = current.postPracticeDistressRecordedAt {
                    LabeledContent("After-practice distress", value: "\(after) of 5")
                    Text("Reported \(recordedAt.formatted(date: .abbreviated, time: .shortened)) · demo question")
                        .font(.subheadline)
                        .foregroundStyle(TendTheme.secondary)
                }
                if let note = current.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(note)
                } else { Text("No note added").foregroundStyle(TendTheme.secondary) }
                if current.completed, practice != nil {
                    Button {
                        showingFeedback = true
                    } label: {
                        Label(current.feedbackUpdatedAt == nil ? "Add a reflection" : "Edit reflection", systemImage: "square.and.pencil")
                            .frame(minHeight: 44)
                    }.accessibilityIdentifier("journey.feedback")
                }
            }
            if let practice {
                Section {
                    NavigationLink {
                        PracticeDetailView(practice: practice, checkInID: nil,
                                           entrySource: .repeated, previousSessionID: current.id)
                    } label: {
                        Label("Practice again", systemImage: "arrow.counterclockwise").frame(minHeight: 44)
                    }.accessibilityIdentifier("journey.repeat")
                }
            }
            if let checkInID = current.checkInID, let record = store.data.checkIns.first(where: { $0.id == checkInID }) {
                Section {
                    NavigationLink { CheckInRecordView(record: record) } label: {
                        Label("View linked check-in", systemImage: "list.clipboard").frame(minHeight: 44)
                    }.accessibilityIdentifier("journey.linkedCheckIn")
                }
            }
        }
        .scrollContentBackground(.hidden).tendScreen().navigationTitle("A moment for you")
        .navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("journey.practiceDetail")
        .sheet(isPresented: $showingFeedback) {
            if let practice {
                NavigationStack {
                    PracticeFeedbackView(practice: practice, draft: current) { showingFeedback = false }
                        .tendScreen()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Cancel") { showingFeedback = false }
                            }
                        }
                }
            }
        }
    }
    private var duration: String {
        let seconds = max(0, Int(current.durationSeconds))
        return "\(seconds / 60)m \(seconds % 60)s"
    }
}

struct ExpiredRecommendationView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ContentUnavailableView {
            Label("This option has expired", systemImage: "clock")
        } description: {
            Text("The one-hour demo window has ended. A new check-in can suggest options for how you feel now.")
        } actions: {
            Button("Start a new check-in") { store.startCheckIn(origin: .onDemand) }
                .buttonStyle(PrimaryButtonStyle())
        }
        .tendScreen()
        .navigationTitle("Previous option")
    }
}
