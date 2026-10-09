import Foundation

struct PlannedReminder: Identifiable, Equatable, Sendable {
    let slotID: String
    let date: Date
    let timezoneID: String
    var id: String { "tend.ema.\(slotID).\(Int(date.timeIntervalSince1970))" }
}

/// Local notifications have a bounded pending queue. Keep at most 60 requests and
/// replenish on foreground entry. Without opening the app, reminders stop after
/// this 20-day window; a production study needs its approved remote delivery service.
enum ReminderPlan {
    static let horizonDays = 20

    static func make(slots: [ReminderSlot], enrolledAt: Date, studyEndDate: Date,
                     now: Date = Date(), calendar: Calendar = .current,
                     completedTodaySlotIDs: Set<String> = []) throws -> [PlannedReminder] {
        try StudyConfiguration.validatePrompts(slots)
        guard studyEndDate > enrolledAt, now < studyEndDate else { return [] }
        let today = calendar.startOfDay(for: now)
        var result: [PlannedReminder] = []
        for offset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            for slot in slots {
                if offset == 0 && completedTodaySlotIDs.contains(slot.id) { continue }
                // A missing spring-forward time advances to the next valid local time.
                // A repeated fall-back time is scheduled only once, at its first occurrence.
                guard let date = calendar.nextDate(after: day.addingTimeInterval(-1),
                    matching: DateComponents(hour: slot.hour, minute: slot.minute, second: 0),
                    matchingPolicy: .nextTime, repeatedTimePolicy: .first),
                    calendar.isDate(date, inSameDayAs: day), date > now,
                    date >= enrolledAt, date < studyEndDate else { continue }
                result.append(PlannedReminder(slotID: slot.id, date: date, timezoneID: calendar.timeZone.identifier))
            }
        }
        return result.sorted { $0.date == $1.date ? $0.slotID < $1.slotID : $0.date < $1.date }
    }
}

struct ReminderRoute: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    let slotID: String?
    let occurrenceDate: Date?
    var openedAt: Date? = Date()

    /// A stale, unknown, or expired notification opens on-demand support.
    /// The response window is one hour from the scheduled occurrence.
    func eligibleSlotID(reminders: [ReminderSlot], completedSlotIDs: Set<String>,
                        enrolledAt: Date, studyEndDate: Date, now: Date = Date(),
                        calendar: Calendar = .current) -> String? {
        guard let slotID, reminders.contains(where: { $0.id == slotID }),
              !completedSlotIDs.contains(slotID), let occurrenceDate,
              now >= enrolledAt, now < studyEndDate,
              occurrenceDate >= enrolledAt, occurrenceDate < studyEndDate,
              CheckInWindow.contains(now, startingAt: occurrenceDate),
              calendar.isDate(occurrenceDate, inSameDayAs: now) else { return nil }
        return slotID
    }
}
