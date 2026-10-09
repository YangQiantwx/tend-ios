import Foundation

/// A check-in becomes available for one hour after its local reminder time.
/// These presentation overrides never change the clock or saved record dates.
enum CheckInWindow {
    static let duration: TimeInterval = 60 * 60

    enum Preview: Equatable, Sendable {
        case live, open, closed

        static func resolve(arguments: [String], dataMode: AppDataMode) -> Self {
            #if DEBUG
            guard dataMode == .demo || dataMode == .uiTesting else { return .live }
            // Fail closed if conflicting preview flags are supplied.
            if arguments.contains("--demo-window-closed") { return .closed }
            if arguments.contains("--demo-window-open") { return .open }
            #endif
            return .live
        }
    }

    static func contains(_ now: Date, startingAt start: Date) -> Bool {
        now >= start && now < start.addingTimeInterval(duration)
    }

    static func activeSlot(reminders: [ReminderSlot], completedSlotIDs: Set<String>,
                           enrolledAt: Date, studyEndDate: Date, now: Date = Date(),
                           calendar: Calendar = .current, preview: Preview = .live) -> ReminderSlot? {
        guard now >= enrolledAt, now < studyEndDate, preview != .closed else { return nil }
        let ordered = reminders.sorted {
            $0.hour * 60 + $0.minute == $1.hour * 60 + $1.minute
                ? $0.id < $1.id
                : $0.hour * 60 + $0.minute < $1.hour * 60 + $1.minute
        }
        if preview == .open {
            // A preview represents one window, so completing it never opens another.
            guard let slot = ordered.first(where: { $0.id == "morning" }) ?? ordered.first,
                  !completedSlotIDs.contains(slot.id) else { return nil }
            return slot
        }
        let available = ordered.filter { !completedSlotIDs.contains($0.id) }
        let day = calendar.startOfDay(for: now)
        return available.first { slot in
            guard let start = calendar.nextDate(after: day.addingTimeInterval(-1),
                matching: DateComponents(hour: slot.hour, minute: slot.minute, second: 0),
                matchingPolicy: .nextTime, repeatedTimePolicy: .first),
                calendar.isDate(start, inSameDayAs: day), start >= enrolledAt else { return false }
            return contains(now, startingAt: start)
        }
    }
}
