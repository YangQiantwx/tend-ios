import SwiftUI

struct PracticePlayerView: View {
    let practice: Practice
    let checkInID: UUID?
    let entrySource: PracticeEntrySource
    let previousSessionID: UUID?
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player: PracticePlayerModel
    @State private var prompt: FinishPrompt?
    @State private var resumeAfterPrompt = false
    @State private var feedback: PracticeSession?
    @State private var saveError: String?
    @State private var didSave = false
    @ScaledMetric(relativeTo: .largeTitle) private var phaseSize = 36

    init(practice: Practice, checkInID: UUID?, audioEnabled: Bool,
         entrySource: PracticeEntrySource? = nil, previousSessionID: UUID? = nil) {
        self.practice = practice
        self.checkInID = checkInID
        self.entrySource = entrySource ?? (checkInID == nil ? .library : .recommendation)
        self.previousSessionID = previousSessionID
        _player = State(initialValue: PracticePlayerModel(practice: practice, audioEnabled: audioEnabled))
    }

    private var isMovement: Bool { practice.category == .movement }
    private var isBreathing: Bool { practice.title.localizedCaseInsensitiveContains("breath") }

    var body: some View {
        NavigationStack {
            Group {
                if let feedback {
                    PracticeFeedbackView(practice: practice, draft: feedback,
                                         allowPostDistress: true) { dismiss() }
                } else {
                    playerContent
                }
            }
            .tendScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if feedback == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { ask(.endEarly) } label: {
                            Image(systemName: "xmark").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Close practice")
                        .accessibilityIdentifier("practice.close")
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .task {
            let isNewSession = !player.hasStarted
            player.start()
            if isNewSession {
                var details = ["practiceID": practice.id, "checkInID": checkInID?.uuidString ?? "",
                               "entrySource": entrySource.rawValue]
                if let previousSessionID { details["previousSessionID"] = previousSessionID.uuidString }
                _ = store.recordEvent(kind: "practice_started", referenceID: player.id.uuidString,
                                      details: details)
            }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { break }
                player.tick()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { player.pause(forBackground: true) }
        }
        .onAppear { store.isPracticePresented = true }
        .onDisappear { player.stop(); store.isPracticePresented = false }
        .alert(item: $prompt) { choice in
            Alert(title: Text(choice == .finish ? "Completed your practice?" : "End this practice?"),
                  message: Text(choice == .finish
                    ? "This records your own report of completion, along with your actual practice time."
                    : "Your time will be saved as ended early. It won't count as a completed practice."),
                  primaryButton: choice == .finish
                    ? .default(Text("I completed this"), action: beginFeedback)
                    : .destructive(Text("End practice"), action: endEarly),
                  secondaryButton: .cancel(Text("Keep practicing")) {
                      if resumeAfterPrompt && scenePhase == .active { player.resume() }
                  })
        }
    }

    private var playerContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(practice.title).font(.title.weight(.medium)).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                PracticeArtwork(isMovement: isMovement,
                                expansion: reduceMotion || !isBreathing ? 0.5 : player.expansion,
                                symbol: practice.symbol)
                    .animation(reduceMotion || player.isPaused ? nil : .linear(duration: 0.25), value: player.expansion)
                    .frame(height: 144).padding(.horizontal, 32)
                VStack(spacing: 8) {
                    Text(phaseLabel).font(TendTheme.display(phaseSize)).multilineTextAlignment(.center)
                    if let phaseDetail {
                        Text(phaseDetail).font(.body).foregroundStyle(TendTheme.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                VStack(spacing: 12) {
                    Text(String(format: "%02d:%02d", player.remaining / 60, player.remaining % 60))
                        .font(.system(.largeTitle, design: .rounded).monospacedDigit())
                        .accessibilityLabel("\(player.remaining / 60) minutes and \(player.remaining % 60) seconds remaining")
                        .accessibilityIdentifier("practice.timer")
                    ProgressView(value: player.progress).tint(TendTheme.forest)
                        .accessibilityLabel("Practice time")
                }
                controls
                if let saveError { Text(saveError).font(.subheadline).foregroundStyle(TendTheme.terracotta) }
                voiceControls
                DisclosureGroup("Steps") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(practice.steps.enumerated()), id: \.offset) { index, step in
                            Text("\(index + 1). \(step)").font(.body)
                        }
                    }
                    .padding(.top, 8)
                }
                .tint(TendTheme.forest)
                .frame(maxWidth: .infinity, alignment: .leading).tendCard()
            }
            .padding(24)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if !player.timerFinished {
                Button {
                    player.isPaused ? player.resume() : player.pause()
                } label: {
                    Label(player.isPaused ? "Resume practice" : "Pause practice",
                          systemImage: player.isPaused ? "play.fill" : "pause.fill")
                }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("practice.pause")
            }
            Button(player.timerFinished ? "I completed this" : "Finish practice") {
                ask(.finish)
            }
            .buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("practice.finish")
            Button("End early") { ask(.endEarly) }
                .font(.subheadline).foregroundStyle(TendTheme.secondary)
                .frame(minHeight: 44).accessibilityIdentifier("practice.endEarly")
        }
    }

    private var voiceControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(get: { player.audioEnabled }, set: { player.setAudioEnabled($0) })) {
                Label("Spoken guide", systemImage: "speaker.wave.2")
            }.tint(TendTheme.forest).accessibilityIdentifier("practice.voice")
            Text("A short introduction, followed by quiet practice.")
                .font(.subheadline).foregroundStyle(TendTheme.secondary)
            if let audioError = player.audioError {
                Text(audioError).font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
        }
    }

    private var phaseLabel: String {
        if player.timerFinished { return "Timer finished" }
        if player.isPaused { return "Practice paused" }
        return practice.playerCue ?? "Follow the steps"
    }

    private var phaseDetail: String? {
        if player.timerFinished { return "Confirm below if you completed the practice." }
        if player.pausedForBackground { return "The timer paused while the app was away." }
        if player.isPaused { return "Resume when you are ready." }
        return nil
    }

    private func ask(_ choice: FinishPrompt) {
        resumeAfterPrompt = !player.isPaused
        player.pause()
        prompt = choice
    }

    private func beginFeedback() {
        player.stop()
        let session = makeSession(completed: true)
        if store.recordSession(session) {
            didSave = true
            feedback = session
        } else {
            saveError = "Couldn't save your completed practice. Your timer is paused; please tap Finish practice to try again."
        }
    }

    private func endEarly() {
        guard !didSave else { return }
        player.stop()
        let session = makeSession(completed: false)
        if store.recordSession(session) {
            didSave = true
            dismiss()
        } else {
            saveError = "Couldn't save your practice. Please try End early again; your timer is paused."
        }
    }

    private func makeSession(completed: Bool) -> PracticeSession {
        var session = player.session(participantID: store.data.settings.participantID,
                                     practiceID: practice.id, checkInID: checkInID,
                                     completed: completed, endedAt: Date())
        session.entrySource = entrySource
        session.previousSessionID = previousSessionID
        return session
    }
}

private enum FinishPrompt: String, Identifiable {
    case finish, endEarly
    var id: String { rawValue }
}
