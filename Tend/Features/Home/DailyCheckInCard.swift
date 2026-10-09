import SwiftUI

struct DailyCheckInCard: View {
    @Environment(AppStore.self) private var store
    @ScaledMetric(relativeTo: .title) private var headingSize: CGFloat = 28

    private var hasDraft: Bool { store.savedDraft != nil }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let slot = store.scheduledSlot(at: context.date)
            VStack(spacing: 8) {
                if hasDraft {
                    Button { store.resumeSavedCheckIn() } label: {
                        primaryLabel("Continue check-in", message: "Pick up where you left off.")
                    }
                    .buttonStyle(CheckInHeroStyle())
                    .accessibilityIdentifier("home.checkIn")
                    .accessibilityLabel("Continue check-in")
                } else if let slot {
                    Button { beginScheduled() } label: {
                        primaryLabel("Check in", message: "A moment for you.")
                    }
                    .buttonStyle(CheckInHeroStyle())
                    .accessibilityIdentifier("home.scheduled.\(slot.id)")
                    .accessibilityLabel("Check in")
                } else {
                    HStack(alignment: .center, spacing: 20) {
                        Image(systemName: "leaf")
                            .font(.title.weight(.light))
                            .foregroundStyle(TendTheme.forest)
                            .accessibilityHidden(true)
                        Text("Small moments of care count.")
                            .font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("home.checkInMessage")
                    }
                    .padding(.vertical, 12)
                    .tendCard()
                }

                Button { store.startCheckIn(origin: .onDemand) } label: {
                    Label("Extra check-in", systemImage: "plus.circle")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(TendTheme.forest)
                .accessibilityIdentifier(hasDraft ? "home.extraCheckIn" : "home.checkIn")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.checkInCard")
        }
    }

    private func primaryLabel(_ title: String, message: String) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(TendTheme.display(headingSize))
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.checkInMessage")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.up.right")
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(TendTheme.onForest.opacity(0.13), in: Circle())
                .accessibilityHidden(true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 144, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func beginScheduled() {
        // The rendered button can be tapped exactly at a boundary; check again here.
        guard let slot = store.scheduledSlot() else { return }
        store.startCheckIn(origin: .scheduled, slotID: slot.id)
    }
}

private struct CheckInHeroStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(TendTheme.onForest)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [TendTheme.forest, TendTheme.sea],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(TendTheme.onForest.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: TendTheme.forest.opacity(0.12), radius: 12, x: 0, y: 5)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}
