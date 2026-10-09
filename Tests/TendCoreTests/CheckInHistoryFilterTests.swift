import Foundation
import XCTest
@testable import TendCore

final class CheckInHistoryFilterTests: XCTestCase {
    private func calendar(timeZone: String = "Asia/Shanghai") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func record(at date: Date, origin: CheckInOrigin = .scheduled, slotID: String? = "morning") -> CheckInRecord {
        CheckInRecord(id: UUID(), participantID: "TEST", startedAt: date, completedAt: date,
            timezoneID: "Asia/Shanghai", origin: origin, slotID: slotID,
            answers: EMAAnswers(distress: 3, willingness: 3, fatigue: 3, pain: 1,
                                physicalFunction: 4, availableTime: .under5),
            ruleVersion: "test", recommendedPracticeIDs: ["movement-break", "grounding"])
    }

    func testWeekUsesCalendarBoundaryAndExcludesNextMonday() {
        let calendar = calendar()
        let monday = date(2026, 10, 5, calendar: calendar)
        let nextMonday = date(2026, 10, 12, calendar: calendar)
        let records = [record(at: monday.addingTimeInterval(-1)), record(at: monday),
                       record(at: nextMonday.addingTimeInterval(-1)), record(at: nextMonday)]
        let result = CheckInHistoryPeriod.week.records(records, around: monday, calendar: calendar)
        XCTAssertEqual(result.map(\.completedAt), [nextMonday.addingTimeInterval(-1), monday])
    }

    func testWeekMatchesJourneysMondayBoundaryRegardlessOfLocaleWeekStart() {
        for firstWeekday in [1, 2, 7] {
            var calendar = calendar()
            calendar.firstWeekday = firstWeekday
            let monday = date(2026, 10, 5, calendar: calendar)
            let tuesday = date(2026, 10, 6, calendar: calendar)
            let sunday = date(2026, 10, 11, hour: 23, calendar: calendar)
            let nextMonday = date(2026, 10, 12, calendar: calendar)
            for anchor in [tuesday, sunday] {
                let interval = CheckInHistoryPeriod.week.interval(containing: anchor, calendar: calendar)
                XCTAssertEqual(interval?.start, monday)
                XCTAssertEqual(interval?.end, nextMonday)
                XCTAssertEqual(CheckInHistoryPeriod.week.moving(1, from: anchor, calendar: calendar), nextMonday)
            }
            let records = [record(at: monday.addingTimeInterval(-1)), record(at: monday),
                           record(at: sunday), record(at: nextMonday)]
            XCTAssertEqual(CheckInHistoryPeriod.week.records(records, around: tuesday, calendar: calendar)
                .map(\.completedAt), [sunday, monday])
        }
    }

    func testMonthIncludesLeapDayAndExcludesMarchMidnight() {
        let calendar = calendar()
        let start = date(2028, 2, 1, calendar: calendar)
        let leapDay = date(2028, 2, 29, hour: 14, calendar: calendar)
        let march = date(2028, 3, 1, calendar: calendar)
        let records = [record(at: start.addingTimeInterval(-1)), record(at: start),
                       record(at: leapDay), record(at: march)]
        let result = CheckInHistoryPeriod.month.records(records, around: leapDay, calendar: calendar)
        XCTAssertEqual(result.map(\.completedAt), [leapDay, start])
    }

    func testDSTWeekIsCalendarWeekInsteadOfFixedSeconds() {
        let calendar = calendar(timeZone: "America/Los_Angeles")
        let monday = date(2026, 3, 2, calendar: calendar)
        let nextMonday = date(2026, 3, 9, calendar: calendar)
        let interval = CheckInHistoryPeriod.week.interval(containing: monday, calendar: calendar)!
        XCTAssertEqual(interval.end, nextMonday)
        XCTAssertEqual(interval.duration, 167 * 3600)
        XCTAssertEqual(CheckInHistoryPeriod.week.moving(1, from: monday, calendar: calendar), nextMonday)
    }

    func testMonthNavigationDoesNotSkipShorterMonthsFromDay31() {
        let calendar = calendar()
        let january31 = date(2026, 1, 31, hour: 20, calendar: calendar)
        XCTAssertEqual(CheckInHistoryPeriod.month.moving(1, from: january31, calendar: calendar),
                       date(2026, 2, 1, calendar: calendar))
        XCTAssertEqual(CheckInHistoryPeriod.month.moving(-1, from: january31, calendar: calendar),
                       date(2025, 12, 1, calendar: calendar))
    }

    func testAllKeepsEveryRecordNewestFirst() {
        let calendar = calendar()
        let old = record(at: date(2025, 1, 1, calendar: calendar))
        let recent = record(at: date(2026, 10, 5, calendar: calendar))
        let result = CheckInHistoryPeriod.all.records([old, recent], around: old.completedAt, calendar: calendar)
        XCTAssertEqual(result.map(\.id), [recent.id, old.id])
        XCTAssertTrue(CheckInHistoryPeriod.all.records([], around: old.completedAt, calendar: calendar).isEmpty)
    }

    func testLabelsUseRecordedSlotAndOriginNotCompletionHour() {
        let date = date(2026, 10, 5, hour: 23, calendar: calendar())
        XCTAssertEqual(CheckInHistoryLabel(record: record(at: date), reminders: []).title, "Morning")
        XCTAssertEqual(CheckInHistoryLabel(record: record(at: date, slotID: "afternoon"), reminders: []).symbol, "sun.max")
        XCTAssertEqual(CheckInHistoryLabel(record: record(at: date, slotID: "evening"), reminders: []).title, "Evening")
        XCTAssertEqual(CheckInHistoryLabel(record: record(at: date, origin: .onDemand, slotID: "morning"), reminders: []).title, "Extra")
        let custom = ReminderSlot(id: "custom", label: "Lunch", hour: 12, minute: 0)
        XCTAssertEqual(CheckInHistoryLabel(record: record(at: date, slotID: "custom"), reminders: [custom]).title, "Lunch")
        XCTAssertEqual(CheckInHistoryLabel(record: record(at: date, slotID: "removed"), reminders: [custom]).title, "Scheduled")
    }
}
