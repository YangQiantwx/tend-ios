import SwiftUI

struct DailyCheckInCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var hasDraft: Bool { store.savedDraft != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: begin) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(hasDraft ? "Continue saved check-in" : "Extra check-in")
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                } else {
                    HStack {
                        Label(hasDraft ? "Continue saved check-in" : "Extra check-in", systemImage: "plus.circle")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            let headingLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            headingLayout {
                Text("Check-ins")
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text("\(store.completedSlotIDs.count) of \(store.data.settings.reminders.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(TendTheme.secondary)
            }
            ForEach(slots) { slot in
                let done = store.completedSlotIDs.contains(slot.id)
                Button {
                    store.startCheckIn(origin: .scheduled, slotID: slot.id)
                } label: {
                    slotContent(slot, done: done)
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

    @ViewBuilder
    private func slotContent(_ slot: ReminderSlot, done: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text(slot.label).font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(format: "%02d:%02d", slot.hour, slot.minute))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(TendTheme.secondary)
                HStack(spacing: 12) {
                    statusIcon(done: done, accessibleSize: true)
                    Text(done ? "Done" : store.isStudyActive ? "Start" : "Study ended")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(TendTheme.forest)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            HStack(spacing: 14) {
                statusIcon(done: done, accessibleSize: false)
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
        }
    }

    private func statusIcon(done: Bool, accessibleSize: Bool) -> some View {
        Image(systemName: done ? "checkmark.circle.fill" : "clock")
            .font(accessibleSize ? .system(size: 22) : .title2)
            .foregroundStyle(done ? TendTheme.sea : TendTheme.forest)
            .frame(width: 36, height: 36)
            .background(TendTheme.sage.opacity(done ? 0.5 : 1), in: Circle())
            .accessibilityHidden(true)
    }
}
