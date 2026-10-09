import SwiftUI

struct SupportOptionsView: View {
    @Environment(AppStore.self) private var store
    let record: CheckInRecord
    let onDone: () -> Void
    private var practices: [Practice] { record.recommendedPracticeIDs.compactMap { store.practice(id: $0) } }
    private var completedIDs: Set<String> {
        Set(store.data.sessions.filter { $0.checkInID == record.id && $0.completed }.map(\.practiceID))
    }
    private var hasCompletion: Bool { !completedIDs.isEmpty }
    private var allCompleted: Bool { practices.allSatisfy { completedIDs.contains($0.id) } }
    private var optionsAvailable: Bool { record.recommendationsAvailable(at: Date()) }
    private var nextPractice: Practice? { practices.first { !completedIDs.contains($0.id) } }
    private var savedEntry: SavedRecommendation? {
        store.data.savedRecommendations?.first { $0.checkInID == record.id }
    }
    private var savedForLater: Bool { savedEntry != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(TendTheme.forest)
                    Text("Check-in saved").font(.subheadline)
                }.padding(.top, 4)
                Text(optionsAvailable ? (hasCompletion ? "Keep going?" : "Choose a practice") : "Options expired")
                    .font(TendTheme.display(34))
                if optionsAvailable {
                    Text("\(record.answers.availableTime.label) available · choose one or both")
                        .font(.subheadline).foregroundStyle(TendTheme.secondary)
                } else {
                    Text("Start a new check-in for current options.")
                        .font(.body).foregroundStyle(TendTheme.secondary)
                }
                if let savedEntry {
                    Label(savedEntry.isAvailable(at: Date())
                          ? "Saved · Today → Saved for later"
                          : "Saved option expired", systemImage: "bookmark.fill")
                        .font(.subheadline).foregroundStyle(TendTheme.forest)
                }
                if optionsAvailable {
                    ForEach(practices) { practice in
                        NavigationLink(value: practice) {
                            OptionCard(practice: practice, completed: completedIDs.contains(practice.id))
                        }.buttonStyle(.plain).accessibilityIdentifier("options.\(practice.category.rawValue)")
                    }
                }
            }.frame(maxWidth: 560).padding(.horizontal, 24).frame(maxWidth: .infinity)
        }.tendScreen()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        if optionsAvailable && !allCompleted {
                            Button(action: saveForLater) {
                                Label(savedForLater ? "Saved" : "Save for later",
                                      systemImage: savedForLater ? "bookmark.fill" : "bookmark")
                                    .font(.subheadline.weight(.medium))
                            }.buttonStyle(SecondaryButtonStyle()).disabled(savedForLater).accessibilityIdentifier("options.save")
                        }
                        if optionsAvailable && !hasCompletion {
                            Button("Skip for now", action: skip).font(.subheadline.weight(.medium))
                                .frame(minWidth: 100, minHeight: 52).accessibilityIdentifier("options.skip")
                        }
                    }
                    if optionsAvailable, hasCompletion, let nextPractice {
                        NavigationLink(value: nextPractice) {
                            Label("Try the other option", systemImage: "arrow.right")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("options.otherOption")
                        Button("Back to Today", action: returnToToday)
                            .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                            .accessibilityIdentifier("options.done")
                    } else if hasCompletion || savedForLater || !optionsAvailable {
                        Button("Back to Today", action: returnToToday)
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityIdentifier("options.done")
                    }
                }.padding(.horizontal, 24).padding(.vertical, 12).background(TendTheme.paper)
            }
    }

    private func saveForLater() {
        _ = store.saveRecommendation(record)
    }
    private func returnToToday() {
        if hasCompletion, !allCompleted, optionsAvailable {
            guard store.saveRecommendation(record) else { return }
        }
        onDone()
    }
    private func skip() {
        if store.recordEvent(kind: "recommendations_skipped", referenceID: record.id.uuidString) { onDone() }
    }
}

private struct OptionCard: View {
    let practice: Practice
    let completed: Bool
    var body: some View {
        HStack(spacing: 16) {
            PracticeSymbol(symbol: practice.symbol, size: 36, color: TendTheme.forest)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 5) {
                Text(practice.title).font(.title3.weight(.semibold))
                Text("\(practice.category.displayTitle) · \(practice.durationSeconds / 60) min")
                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
            Spacer(minLength: 0)
            if completed {
                Image(systemName: "checkmark.circle.fill")
            } else {
                Image(systemName: "arrow.right")
            }
        }
        .padding(16).frame(minHeight: 84)
        .background(practice.category == .movement ? TendTheme.sage : TendTheme.clay,
                    in: RoundedRectangle(cornerRadius: 20))
    }
}
