import SwiftUI

struct DailyCheckInCard: View {
    @Environment(AppStore.self) private var store

    private var hasDraft: Bool { store.savedDraft != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: begin) {
                HStack {
                    Label(hasDraft ? "Continue saved check-in" : "Extra check-in", systemImage: "plus.circle")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("home.checkIn")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func begin() {
        if hasDraft { store.resumeSavedCheckIn() }
        else { store.startCheckIn(origin: .onDemand) }
    }
}

struct ReminderTimeline: View {
    @Environment(AppStore.self) private var store

    private var slots: [ReminderSlot] {
        store.data.settings.reminders.sorted { left, right in
            let leftDone = store.completedSlotIDs.contains(left.id)
            let rightDone = store.completedSlotIDs.contains(right.id)
            if leftDone != rightDone { return !leftDone }
            return left.hour * 60 + left.minute < right.hour * 60 + right.minute
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Check-ins")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(store.completedSlotIDs.count) of \(store.data.settings.reminders.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(TendTheme.secondary)
            }
            ForEach(slots) { slot in
                let done = store.completedSlotIDs.contains(slot.id)
                Button {
                    store.startCheckIn(origin: .scheduled, slotID: slot.id)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: done ? "checkmark.circle.fill" : "clock")
                            .font(.title2)
                            .foregroundStyle(done ? TendTheme.sea : TendTheme.forest)
                            .frame(width: 36, height: 36)
                            .background(TendTheme.sage.opacity(done ? 0.5 : 1), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(slot.label) · \(String(format: "%02d:%02d", slot.hour, slot.minute))")
                                .font(.body.weight(.semibold))
                        }
                        Spacer(minLength: 4)
                        if !done && store.isStudyActive {
                            Text("Start").font(.body.weight(.semibold))
                                .foregroundStyle(TendTheme.forest)
                            Image(systemName: "arrow.right")
                                .foregroundStyle(TendTheme.forest)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                    .background(done ? TendTheme.sage.opacity(0.35) : TendTheme.surface,
                                in: RoundedRectangle(cornerRadius: 18))
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .disabled(done || !store.isStudyActive)
                .accessibilityLabel("\(slot.label) scheduled check-in, \(String(format: "%02d:%02d", slot.hour, slot.minute)), \(done ? "completed" : store.isStudyActive ? "start" : "study ended")")
                .accessibilityIdentifier("home.scheduled.\(slot.id)")
            }
        }
        .padding(.vertical, 4)
    }
}
