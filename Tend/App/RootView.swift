import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(TendTheme.palettePreferenceKey) private var paletteRawValue = TendPalette.ocean.rawValue
    @State private var selectedTab = 0
    @State private var focusPractices = false
    @State private var openSaved = false

    var body: some View {
        @Bindable var store = store
        Group {
            if store.data.settings.onboardingComplete {
                TabView(selection: $selectedTab) {
                    HomeView(focusPractices: $focusPractices, openSaved: $openSaved)
                        .tabItem { Label("Today", systemImage: "sun.horizon") }.tag(0)
                    QandATabView()
                        .tabItem { Label("Q&A", systemImage: "questionmark.bubble") }.tag(1)
                    JourneyView().tabItem { Label("Journey", systemImage: "chart.xyaxis.line") }.tag(2)
                    ProfileView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
                }
                .tint(TendTheme.forest)
                .id(paletteRawValue)
            } else {
                WelcomeView().id(paletteRawValue)
            }
        }
        .fullScreenCover(item: $store.activeCheckIn) { presentation in
            CheckInFlowView(draft: presentation.draft).environment(store)
        }
        .alert(store.persistenceError == nil ? "Your saved records are safe" : "Couldn't save your change", isPresented: Binding(get: { store.persistenceError != nil || store.draftRecoveryMessage != nil }, set: { if !$0 { store.persistenceError = nil; store.draftRecoveryMessage = nil } })) {
            Button("OK") { store.persistenceError = nil; store.draftRecoveryMessage = nil }
        } message: { Text(store.persistenceError ?? store.draftRecoveryMessage ?? "Please try again.") }
        .confirmationDialog("You have an unfinished check-in", isPresented: Binding(
            get: { store.pendingCheckInRequest != nil },
            set: { if !$0 { store.pendingCheckInRequest = nil } }), titleVisibility: .visible,
                            presenting: store.pendingCheckInRequest) { request in
                Button("Resume saved check-in") { store.resumeSavedCheckIn() }
                Button("Discard and start a new check-in", role: .destructive) { store.replaceDraftAndStartCheckIn(request: request) }
                Button("Cancel", role: .cancel) { store.pendingCheckInRequest = nil }
        } message: { _ in
            if let draft = store.savedDraft {
                Text("Your answers from \(draft.startedAt.formatted(date: .abbreviated, time: .shortened)) are saved. Resume them, or begin a fresh check-in about this moment.")
            }
        }
        .task {
            consumePendingReminder()
            consumePendingSaved()
            await store.refreshNotificationStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                consumePendingReminder()
                consumePendingSaved()
                Task { await store.refreshNotificationStatus() }
            }
        }
        .onChange(of: store.data.settings.onboardingComplete) { _, complete in
            if complete { consumePendingReminder(); consumePendingSaved() }
        }
        .onChange(of: store.activeCheckIn?.id) { _, id in
            if id == nil { consumePendingReminder(); consumePendingSaved() }
        }
        .onChange(of: store.isPracticePresented) { _, isPresented in
            if !isPresented { consumePendingReminder(); consumePendingSaved() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tendReminderOpened)) { _ in
            consumePendingReminder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tendSavedReminderOpened)) { _ in
            consumePendingSaved()
        }
        .onOpenURL { url in
            if url.scheme == "tend", url.host == "check-in", store.data.settings.onboardingComplete {
                store.startCheckIn(origin: .onDemand)
            }
        }
    }

    private func consumePendingReminder() {
        guard store.data.settings.onboardingComplete, store.activeCheckIn == nil,
              !store.isPracticePresented, store.pendingCheckInRequest == nil,
              let route = NotificationInbox.pending else { return }
        guard store.recordReminderOpened(route) else { return }
        let slotID = route.eligibleSlotID(reminders: store.data.settings.reminders,
            completedSlotIDs: store.completedSlotIDs, enrolledAt: store.data.settings.enrolledAt,
            studyEndDate: store.studyEndDate)
        selectedTab = 0
        store.startCheckIn(origin: slotID == nil ? .onDemand : .scheduled, slotID: slotID)
        // If local saving failed, keep the route for a later successful retry.
        if store.activeCheckIn != nil || store.pendingCheckInRequest != nil { NotificationInbox.acknowledge(route.id) }
    }

    private func consumePendingSaved() {
        guard store.data.settings.onboardingComplete, store.activeCheckIn == nil,
              !store.isPracticePresented, store.pendingCheckInRequest == nil,
              NotificationInbox.shouldOpenSaved else { return }
        selectedTab = 0
        openSaved = true
        NotificationInbox.acknowledgeSaved()
    }
}
