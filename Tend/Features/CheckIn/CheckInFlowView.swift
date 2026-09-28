import SwiftUI

struct CheckInFlowView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var draft: CheckInDraft
    @State private var record: CheckInRecord?
    @State private var path: [Practice] = []
    @State private var showLeave = false

    private var canContinue: Bool {
        switch draft.page {
        case 0: return draft.ratings["distress"] != nil && draft.ratings["willingness"] != nil
        case 1: return draft.ratings["fatigue"] != nil && draft.ratings["pain"] != nil
        default: return draft.ratings["physicalFunction"] != nil && draft.availableTime != nil
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let record { SupportOptionsView(record: record, onDone: { dismiss() }) }
                else { assessment }
            }
            .tendScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if path.isEmpty {
                        Button { record == nil ? (showLeave = true) : dismiss() } label: {
                            Image(systemName: "xmark").font(.body).frame(width: 44, height: 44)
                        }.accessibilityLabel("Close check-in").accessibilityIdentifier("ema.close")
                    }
                }
                ToolbarItem(placement: .principal) {
                    if record == nil { Text("Check-in").font(.subheadline.weight(.semibold)) }
                }
            }
            .navigationDestination(for: Practice.self) { practice in
                if let record, !record.recommendationsAvailable(at: Date()) {
                    ExpiredCheckInOptionView(onBackToToday: { dismiss() })
                } else {
                    PracticeDetailView(practice: practice, checkInID: record?.id,
                                       onExpired: { dismiss() }) {
                        guard let otherID = record?.recommendedPracticeIDs.first(where: { $0 != practice.id }),
                              let other = store.practice(id: otherID) else { return }
                        path = [other]
                    }
                }
            }
        }
        .tint(TendTheme.forest)
        .onChange(of: draft) { _, value in if record == nil { _ = store.saveDraft(value) } }
        .confirmationDialog("Come back when you're ready", isPresented: $showLeave, titleVisibility: .visible) {
            Button("Save and close") { if store.saveDraft(draft) { dismiss() } }
            Button("Discard this check-in", role: .destructive) {
                if store.discardSavedDraft() { dismiss() }
            }.accessibilityIdentifier("ema.discard")
            Button("Keep going", role: .cancel) { }
        } message: { Text("Your answers will be here when you return.") }
        .alert("Couldn't save your answers", isPresented: Binding(get: { store.persistenceError != nil }, set: { if !$0 { store.persistenceError = nil } })) {
            Button("OK") { store.persistenceError = nil }
        } message: { Text(store.persistenceError ?? "Please try again.") }
    }

    private var assessment: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            ForEach(0..<3) { index in Capsule().fill(index <= draft.page ? TendTheme.forest : TendTheme.line).frame(height: 4) }
                        }
                        Text("\(draft.page + 1) of 3")
                            .font(.title2.weight(.semibold))
                    }.id("top")
                    CheckInQuestions(draft: $draft)
                        .id(draft.page).transition(.opacity)
                    if draft.page > 0 {
                        Button { changePage(-1); proxy.scrollTo("top", anchor: .top) } label: {
                            Label("Previous questions", systemImage: "arrow.left").font(.subheadline)
                                .frame(minHeight: 44)
                        }.accessibilityIdentifier("ema.back")
                    }
                }.frame(maxWidth: 560).padding(20).frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if draft.page < 2 { changePage(1); proxy.scrollTo("top", anchor: .top) }
                    else { record = store.submitCheckIn(draft) }
                } label: {
                    HStack { Text(draft.page < 2 ? "Continue" : "Find my options"); Image(systemName: "arrow.right") }
                }.buttonStyle(PrimaryButtonStyle()).disabled(!canContinue)
                    .accessibilityIdentifier("ema.continue")
                    .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 12)
                    .background(TendTheme.paper)
            }
        }
    }

    private func changePage(_ offset: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { draft.page += offset }
    }
}

private struct ExpiredCheckInOptionView: View {
    let onBackToToday: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("This option has expired", systemImage: "clock")
        } description: {
            Text("The one-hour demo window has ended. Start a new check-in from Today for current options.")
        } actions: {
            Button("Back to Today", action: onBackToToday)
                .buttonStyle(PrimaryButtonStyle())
        }
        .tendScreen()
        .navigationTitle("Previous option")
    }
}

private struct CheckInQuestions: View {
    @Binding var draft: CheckInDraft
    var body: some View {
        VStack(spacing: 28) {
            switch draft.page {
            case 0:
                RatingQuestionView(number: 1, question: "How distressed do you feel right now?", key: "distress", lower: "Not at all", upper: "Extremely", selection: binding("distress"))
                Divider().overlay(TendTheme.line)
                RatingQuestionView(number: 2, question: "How willing are you to do something right now to help manage how you are feeling?", key: "willingness", lower: "Not at all willing", upper: "Extremely willing", selection: binding("willingness"))
            case 1:
                RatingQuestionView(number: 3, question: "How fatigued do you feel right now?", key: "fatigue", lower: "Not at all", upper: "Extremely", selection: binding("fatigue"))
                Divider().overlay(TendTheme.line)
                RatingQuestionView(number: 4, question: "How much pain are you experiencing right now?", key: "pain", lower: "None", upper: "Severe", selection: binding("pain"))
            default:
                RatingQuestionView(number: 5, question: "How able are you to carry out your everyday physical activities right now?", key: "physicalFunction", lower: "Not at all able", upper: "Extremely able", selection: binding("physicalFunction"))
                Divider().overlay(TendTheme.line)
                TimeQuestionView(selection: $draft.availableTime)
            }
        }
    }
    private func binding(_ key: String) -> Binding<Int?> {
        Binding(get: { draft.ratings[key] }, set: { draft.ratings[key] = $0 })
    }
}
