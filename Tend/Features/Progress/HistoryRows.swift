import SwiftUI

struct CheckInHistoryRow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let record: CheckInRecord
    var showsChevron = true
    var showsDate = true
    private var label: CheckInHistoryLabel { CheckInHistoryLabel(record: record, reminders: store.data.settings.reminders) }

    var body: some View {
        NavigationLink { CheckInRecordView(record: record) } label: {
            HStack(spacing: 16) {
                Image(systemName: label.symbol)
                    .font(.title3.weight(.medium))
                    .frame(width: 44, height: 48)
                    .background(TendTheme.sage, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        title
                        timestamp
                    }.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    title.frame(maxWidth: .infinity, alignment: .leading)
                    timestamp
                }
                if showsChevron {
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        .foregroundStyle(TendTheme.secondary).accessibilityHidden(true)
                }
            }
            .frame(minHeight: 58).padding(.vertical, 6).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("journey.checkin.\(record.id.uuidString)")
        .accessibilityLabel("\(label.title) check-in, \(record.completedAt.formatted(date: .abbreviated, time: .shortened))")
    }

    private var title: some View {
        Text(label.title).font(.body.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var timestamp: some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
            if showsDate { Text(record.completedAt.formatted(.dateTime.month(.abbreviated).day())) }
            Text(record.completedAt.formatted(.dateTime.hour().minute()))
        }
        .font(.subheadline).foregroundStyle(TendTheme.secondary)
        .monospacedDigit().fixedSize(horizontal: false, vertical: true)
    }
}

struct PracticeHistoryRow: View {
    @Environment(AppStore.self) private var store
    let session: PracticeSession
    var showsChevron = true
    var body: some View {
        NavigationLink { PracticeSessionRecordView(session: session) } label: {
            HStack(spacing: 14) {
                Image(systemName: session.completed ? "checkmark.circle" : "pause.circle")
                    .font(.title3).frame(width: 44, height: 48)
                    .background(TendTheme.clay, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityLabel(session.completed ? "Completed" : "Ended early")
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.practice(id: session.practiceID)?.title ?? "Practice").font(.body.weight(.medium))
                    Text(session.completed ? durationLabel : "Ended early · \(durationLabel)")
                        .font(.subheadline).foregroundStyle(TendTheme.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(session.endedAt.formatted(.dateTime.month(.abbreviated).day()))
                    Text(session.endedAt.formatted(.dateTime.hour().minute()))
                }.font(.subheadline).foregroundStyle(TendTheme.secondary).fixedSize()
                if showsChevron { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(TendTheme.secondary) }
            }.frame(minHeight: 58).padding(.vertical, 6).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("journey.session.\(session.id.uuidString)")
    }
    private var durationLabel: String {
        let seconds = max(0, Int(session.durationSeconds))
        return seconds < 60 ? "\(seconds) sec" : "\(seconds / 60) min"
    }
}
