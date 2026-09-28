import SwiftUI

struct CheckInHistoryRow: View {
    let record: CheckInRecord
    var showsChevron = true
    var body: some View {
        NavigationLink { CheckInRecordView(record: record) } label: {
            HStack(spacing: 14) {
                Image(systemName: record.origin == .scheduled ? "sun.max" : "heart")
                    .frame(width: 44, height: 48).background(TendTheme.sage, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.origin == .scheduled ? "Scheduled check-in" : "On-demand check-in").font(.body.weight(.medium))
                    Text(record.completedAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(TendTheme.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if showsChevron { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(TendTheme.secondary) }
            }.frame(minHeight: 58).padding(.vertical, 6).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("journey.checkin.\(record.id.uuidString)")
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
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.practice(id: session.practiceID)?.title ?? "Practice").font(.body.weight(.medium))
                    Text(session.completed ? "Completed · Self-reported" : "Ended early").font(.subheadline).foregroundStyle(TendTheme.secondary)
                    Text(session.endedAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(TendTheme.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if showsChevron { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(TendTheme.secondary) }
            }.frame(minHeight: 58).padding(.vertical, 6).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("journey.session.\(session.id.uuidString)")
    }
}
