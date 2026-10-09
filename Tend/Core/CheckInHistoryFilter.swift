import Foundation

/// Calendar periods use local wall time and a half-open interval so a record
/// at midnight belongs to exactly one week or month, including across DST.
enum CheckInHistoryPeriod: String, CaseIterable, Identifiable {
    case week = "Week", month = "Month", all = "All"
    var id: String { rawValue }

    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .week:
            // Journey defines This week as Monday–Sunday, independent of locale.
            var weekCalendar = calendar
            weekCalendar.firstWeekday = 2
            return weekCalendar.dateInterval(of: .weekOfYear, for: date)
        case .month: return calendar.dateInterval(of: .month, for: date)
        case .all: return nil
        }
    }

    func records(_ records: [CheckInRecord], around date: Date, calendar: Calendar = .current) -> [CheckInRecord] {
        let interval = interval(containing: date, calendar: calendar)
        return records.filter { record in
            guard let interval else { return true }
            return record.completedAt >= interval.start && record.completedAt < interval.end
        }.sorted { $0.completedAt > $1.completedAt }
    }

    func moving(_ offset: Int, from date: Date, calendar: Calendar = .current) -> Date {
        guard let interval = interval(containing: date, calendar: calendar) else { return date }
        let component: Calendar.Component = self == .week ? .weekOfYear : .month
        return calendar.date(byAdding: component, value: offset, to: interval.start) ?? date
    }
}

struct CheckInHistoryLabel {
    let title: String
    let symbol: String

    init(record: CheckInRecord, reminders: [ReminderSlot]) {
        guard record.origin == .scheduled else {
            title = "Extra"
            symbol = "heart"
            return
        }
        switch record.slotID?.lowercased() {
        case "morning": title = "Morning"; symbol = "sunrise"
        case "afternoon": title = "Afternoon"; symbol = "sun.max"
        case "evening": title = "Evening"; symbol = "moon.stars"
        default:
            // A custom or historical slot must not be inferred from completion time.
            title = reminders.first(where: { $0.id == record.slotID })?.label ?? "Scheduled"
            symbol = "clock"
        }
    }
}
