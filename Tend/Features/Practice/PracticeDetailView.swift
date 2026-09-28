import SwiftUI

struct PracticeDetailView: View {
    let practice: Practice
    var checkInID: UUID? = nil
    var entrySource: PracticeEntrySource? = nil
    var previousSessionID: UUID? = nil
    var onExpired: (() -> Void)? = nil
    var onContinueToOther: (() -> Void)? = nil
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 36
    @State private var activePractice: PracticePresentation?
    @State private var alert: PracticeDetailAlert?
    @State private var selectionRecorded = false

    private var isMovement: Bool { practice.category == .movement }
    private var isSaved: Bool { store.data.savedPracticeIDs.contains(practice.id) }
    private var priorSession: PracticeSession? {
        guard let checkInID else { return nil }
        return store.data.sessions.filter {
            $0.practiceID == practice.id && $0.checkInID == checkInID && $0.completed
        }.max { $0.endedAt < $1.endedAt }
    }
    private var completed: Bool { priorSession != nil }
    private var otherPractice: Practice? {
        guard let checkInID, onContinueToOther != nil,
              let record = store.data.checkIns.first(where: { $0.id == checkInID }),
              let otherID = record.recommendedPracticeIDs.first(where: { $0 != practice.id }),
              !store.data.sessions.contains(where: { $0.checkInID == checkInID && $0.practiceID == otherID && $0.completed })
        else { return nil }
        return store.practice(id: otherID)
    }
    private var resolvedSource: PracticeEntrySource {
        entrySource ?? (completed ? .repeated : (checkInID == nil ? .library : .recommendation))
    }
    private var isRepeat: Bool { completed || resolvedSource == .repeated }
    private var recommendationExpired: Bool {
        guard let checkInID else { return false }
        return !store.data.checkIns.contains { $0.id == checkInID && $0.recommendationsAvailable(at: Date()) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                ZStack(alignment: .bottom) {
                    PracticeArtwork(isMovement: isMovement, symbol: practice.symbol)
                        .frame(height: 168).frame(maxWidth: .infinity)
                    if isMovement {
                        Label("Video demonstration placeholder", systemImage: "video")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TendTheme.ink)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(TendTheme.surface, in: Capsule())
                            .padding(.bottom, 4)
                    }
                }
                .accessibilityElement(children: .combine)
                if completed {
                    Label("Practice completed", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium)).foregroundStyle(TendTheme.forest)
                        .tendCard(TendTheme.sage)
                        .accessibilityIdentifier("practice.completed")
                }
                instructions
                Label("Stop if uncomfortable", systemImage: "heart")
                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
        }
        .tendScreen()
        .task {
            if !selectionRecorded {
                selectionRecorded = store.recordEvent(kind: "practice_selected", referenceID: practice.id,
                                                      details: ["checkInID": checkInID?.uuidString ?? "",
                                                                "entrySource": resolvedSource.rawValue,
                                                                "previousSessionID": (previousSessionID ?? priorSession?.id)?.uuidString ?? ""])
            }
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if !store.toggleSaved(practice) { alert = .saveFailure }
                } label: {
                    Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 44)
                }
                .accessibilityLabel(isSaved ? "Remove practice from Saved" : "Save practice to Saved")
                .accessibilityIdentifier("practice.save")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if completed, let otherPractice, let onContinueToOther {
                    Button {
                        if recommendationExpired { alert = .expired }
                        else { onContinueToOther() }
                    } label: {
                        Label("Try \(otherPractice.title)", systemImage: "arrow.right")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("practice.otherOption")
                }
                if isRepeat {
                    Button(action: startPractice) {
                        Label("Practice again", systemImage: "play.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("practice.start")
                } else {
                    Button(action: startPractice) {
                        Label("Start practice", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("practice.start")
                }
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
            .background(TendTheme.paper)
        }
        .fullScreenCover(item: $activePractice) { presentation in
            PracticePlayerView(practice: presentation.practice, checkInID: presentation.checkInID,
                               audioEnabled: store.data.settings.audioEnabled,
                               entrySource: presentation.entrySource,
                               previousSessionID: presentation.previousSessionID)
        }
        .alert(item: $alert) { reason in
            switch reason {
            case .saveFailure:
                Alert(title: Text("Couldn't save that change"),
                      message: Text("Please try again. Your saved practices have not changed."),
                      dismissButton: .default(Text("OK")))
            case .expired:
                Alert(title: Text("This option has expired"),
                      message: Text("The one-hour demo window has ended. Start a new check-in from Today for current options."),
                      primaryButton: .default(Text(onExpired == nil ? "Go back" : "Back to Today")) {
                          if let onExpired { onExpired() }
                          else { dismiss() }
                      },
                      secondaryButton: .cancel(Text("Stay here")))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(practice.title).font(TendTheme.display(titleSize))
                .accessibilityAddTraits(.isHeader)
            Label(durationLabel, systemImage: "clock")
                .font(.subheadline).foregroundStyle(TendTheme.secondary)
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let first = practice.steps.first {
                Text(first).font(.body).fixedSize(horizontal: false, vertical: true)
            }
            if practice.steps.count > 1 {
                DisclosureGroup("All steps") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(practice.steps.dropFirst().enumerated()), id: \.offset) { index, step in
                            Text("\(index + 2). \(step)").font(.body)
                        }
                    }
                    .padding(.top, 8)
                }
                .tint(TendTheme.forest)
            }
        }
        .tendCard()
    }

    private var durationLabel: String {
        practice.durationSeconds >= 60 ? "\(practice.durationSeconds / 60) min" : "\(practice.durationSeconds) sec"
    }

    private func startPractice() {
        guard isRepeat || !recommendationExpired else {
            alert = .expired
            return
        }
        activePractice = PracticePresentation(
            practice: practice,
            checkInID: isRepeat ? nil : checkInID,
            entrySource: isRepeat ? .repeated : resolvedSource,
            previousSessionID: isRepeat ? (priorSession?.id ?? previousSessionID) : previousSessionID
        )
    }
}

private struct PracticePresentation: Identifiable {
    let id = UUID()
    let practice: Practice
    let checkInID: UUID?
    let entrySource: PracticeEntrySource
    let previousSessionID: UUID?
}

private enum PracticeDetailAlert: String, Identifiable {
    case saveFailure, expired
    var id: String { rawValue }
}
