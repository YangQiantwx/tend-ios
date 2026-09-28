import Foundation

struct PlannedSavedReminder: Identifiable, Equatable, Sendable {
    let savedID: UUID
    let checkInID: UUID
    let date: Date
    var id: String { "tend.saved.\(savedID.uuidString)" }
}

enum SavedReminderPlan {
    /// Reserve four requests alongside the sixty scheduled check-in requests.
    static let capacity = 4

    static func make(saved: [SavedRecommendation], sessions: [PracticeSession],
                     studyEndDate: Date, now: Date = Date()) -> [PlannedSavedReminder] {
        let completed = Dictionary(grouping: sessions.filter(\.completed)) { $0.checkInID }
        return Array(saved.compactMap { item -> PlannedSavedReminder? in
            guard item.isAvailable(at: now), item.savedAt <= now,
                  item.practiceIDs.contains(where: { practiceID in
                      !(completed[item.checkInID] ?? []).contains { $0.practiceID == practiceID }
                  }) else { return nil }
            let date = max(item.savedAt.addingTimeInterval(60),
                           item.expiresAt.addingTimeInterval(-15 * 60))
            // Do not re-deliver an earlier reminder on each foreground refresh.
            guard date > now, date < item.expiresAt, date < studyEndDate else { return nil }
            return PlannedSavedReminder(savedID: item.id, checkInID: item.checkInID, date: date)
        }.sorted {
            $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date
        }.prefix(capacity))
    }
}
