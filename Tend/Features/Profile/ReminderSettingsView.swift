import SwiftUI

struct ReminderSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var reminders: [ReminderSlot]
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(reminders: [ReminderSlot]) { _reminders = State(initialValue: reminders) }

    var body: some View {
        Form {
            Section {
                Text("Choose three different times in your local time.")
                    .font(.body)
            }
            Section("Daily check-ins") {
                ForEach(Array(reminders.enumerated()), id: \.element.id) { index, slot in
                    DatePicker(slot.label, selection: timeBinding(at: index), displayedComponents: .hourAndMinute)
                        .tint(TendTheme.forest).accessibilityIdentifier("reminders.time.\(slot.id)")
                }
            }
            Section {
                Label(store.notificationsStatus, systemImage: "bell")
                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(TendTheme.terracotta).accessibilityIdentifier("reminders.error") }
            }
        }
        .scrollContentBackground(.hidden).tendScreen()
        .navigationTitle("Check-in times").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving…" : "Save") { save() }
                    .disabled(isSaving).accessibilityIdentifier("reminders.save")
            }
        }
    }

    private func timeBinding(at index: Int) -> Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: reminders[index].hour, minute: reminders[index].minute, second: 0, of: Date()) ?? Date()
        }, set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminders[index].hour = components.hour ?? reminders[index].hour
            reminders[index].minute = components.minute ?? reminders[index].minute
            errorMessage = nil
        })
    }
    private func save() {
        do { try StudyConfiguration.validatePrompts(reminders) }
        catch { errorMessage = error.localizedDescription; return }
        isSaving = true
        Task {
            if await store.updateReminders(reminders) { dismiss() }
            else { errorMessage = store.persistenceError ?? "We couldn’t save your reminder times. Please try again." }
            isSaving = false
        }
    }
}
