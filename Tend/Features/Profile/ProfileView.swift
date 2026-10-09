import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @AppStorage(TendTheme.palettePreferenceKey) private var paletteRawValue = TendPalette.ocean.rawValue
    @ScaledMetric(relativeTo: .title) private var nameSize = 30
    @State private var updatingNotifications = false
    @State private var editingName = false
    @State private var draftName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    profileCard
                    appearanceCard
                    reminderCard
                    practiceCard
                    studyCard
                    helpCard
                }
                .padding(24)
            }
            .tendScreen()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Edit name", isPresented: $editingName) {
                TextField("Name", text: $draftName).textContentType(.givenName)
                Button("Cancel", role: .cancel) { }
                Button("Save", action: saveName)
            } message: {
                Text("This name appears on your device.")
            }
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Profile")
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 32, weight: .light))
                    .frame(width: 64, height: 64)
                    .background(TendTheme.sage, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.data.settings.displayName.isEmpty ? "Add your name" : store.data.settings.displayName)
                        .font(TendTheme.display(nameSize))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Button("Edit name") {
                draftName = store.data.settings.displayName
                editingName = true
            }
            .frame(minHeight: 44)
            .tint(TendTheme.forest)
            .accessibilityIdentifier("profile.editName")
            Divider().overlay(TendTheme.line)
            NavigationLink { AccountStatusView() } label: {
                settingsRow("Account details", symbol: "person.crop.circle")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.accountDetails")
        }
        .tendCard()
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Check-in reminders")
            NavigationLink {
                ReminderSettingsView(reminders: store.data.settings.reminders)
            } label: {
                settingsRow("Reminder times", subtitle: reminderSummary, symbol: "clock")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.reminders")
            Divider().overlay(TendTheme.line)
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(get: { store.data.settings.notificationsEnabled }, set: setNotificationsEnabled)) {
                    Label("Notifications", systemImage: "bell")
                }
                .tint(TendTheme.forest)
                .disabled(updatingNotifications || !store.dataMode.allowsSystemNotifications)
                .accessibilityIdentifier("profile.notifications")
                Text(store.notificationsStatus)
                    .font(.subheadline)
                    .foregroundStyle(TendTheme.secondary)
                if updatingNotifications { ProgressView().controlSize(.small) }
            }
            .padding(.vertical, 12)
        }
        .tendCard()
    }

    private var practiceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Practice")
            Toggle(isOn: audioBinding) {
                Label("Spoken guidance", systemImage: "speaker.wave.2")
            }
            .tint(TendTheme.forest)
            .frame(minHeight: 44)
            .accessibilityIdentifier("profile.audio")
        }
        .tendCard()
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Appearance")
            HStack(alignment: .top, spacing: 12) {
                ForEach(TendPalette.allCases) { palette in
                    themeOption(palette)
                }
            }
        }
        .tendCard()
    }

    private func themeOption(_ palette: TendPalette) -> some View {
        let selected = paletteRawValue == palette.rawValue
        return Button {
            paletteRawValue = palette.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                LandscapeView(palette: palette)
                    .frame(height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                HStack(spacing: 6) {
                    Text(palette.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(TendTheme.forest)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(TendTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(selected ? TendTheme.forest : TendTheme.line, lineWidth: selected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(palette.title) theme")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("profile.colorTheme.\(palette.rawValue)")
    }

    private var studyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Study")
                .padding(.bottom, 8)
            NavigationLink { AboutTendView() } label: {
                settingsRow("Study information", symbol: "info.circle")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.study")
            Divider().overlay(TendTheme.line)
            NavigationLink { FitbitConnectionView() } label: {
                settingsRow("Fitbit", subtitle: store.data.fitbitDemoConnection?.isConnected == true
                            ? "Demo connection active" : "Try demo connection", symbol: "applewatch")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.fitbit")
            Divider().overlay(TendTheme.line)
            NavigationLink { ResearchPreviewView() } label: {
                settingsRow("Study data & export", symbol: "chart.bar.doc.horizontal")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.research")
        }
        .tendCard()
    }

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Help")
                .padding(.bottom, 8)
            NavigationLink { LearningNoteView() } label: {
                settingsRow("Learn about stress", symbol: "book.closed")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.learn")
            Divider().overlay(TendTheme.line)
            NavigationLink { FrequentlyAskedQuestionsView() } label: {
                settingsRow("Q&A", symbol: "questionmark.bubble")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.faq")
            Divider().overlay(TendTheme.line)
            NavigationLink {
                ContactSupportView(kind: .technicalSupport)
            } label: {
                settingsRow("Technical support", symbol: "wrench.and.screwdriver")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.technicalSupport")
            Divider().overlay(TendTheme.line)
            NavigationLink {
                ContactSupportView(kind: .studyTeam)
            } label: {
                settingsRow("Contact study team", symbol: "person.2")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.contactStudyTeam")
        }
        .tendCard()
    }

    private var audioBinding: Binding<Bool> {
        Binding(get: { store.data.settings.audioEnabled }, set: { enabled in
            var settings = store.data.settings
            settings.audioEnabled = enabled
            _ = store.updateSettings(settings)
        })
    }

    private var reminderSummary: String {
        store.data.settings.reminders
            .map { String(format: "%02d:%02d", $0.hour, $0.minute) }
            .joined(separator: " · ")
    }

    private func settingsRow(_ title: String, subtitle: String? = nil, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium))
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(TendTheme.secondary)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TendTheme.secondary)
        }
        .padding(.vertical, 12)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func saveName() {
        var settings = store.data.settings
        settings.displayName = String(draftName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        _ = store.updateSettings(settings)
    }

    private func setNotificationsEnabled(_ enabled: Bool) {
        updatingNotifications = true
        Task {
            await store.setNotificationsEnabled(enabled)
            updatingNotifications = false
        }
    }
}
