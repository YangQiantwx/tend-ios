import Foundation
import XCTest
@testable import TendCore

final class ReminderPlanTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/New_York")!
        return value
    }
    private var slots: [ReminderSlot] {
        [ReminderSlot(id: "morning", label: "Morning", hour: 10, minute: 0),
         ReminderSlot(id: "afternoon", label: "Afternoon", hour: 14, minute: 0),
         ReminderSlot(id: "evening", label: "Evening", hour: 19, minute: 0)]
    }

    func testTwentyLocalDaysContainAtMostSixtyFutureReminders() throws {
        let enrolled = date(2026, 9, 8, 8)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 56, to: enrolled))
        let plan = try ReminderPlan.make(slots: slots, enrolledAt: enrolled, studyEndDate: end,
                                         now: enrolled, calendar: calendar)
        XCTAssertEqual(plan.count, 60)
        XCTAssertEqual(Set(plan.map(\.id)).count, 60)
        XCTAssertEqual(Set(plan.map { calendar.startOfDay(for: $0.date) }).count, 20)
        XCTAssertTrue(plan.allSatisfy { $0.date > enrolled && $0.date < end })
    }

    func testAlreadyPassedTimesAreNotBackfilled() throws {
        let enrolled = date(2026, 9, 8, 8)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 56, to: enrolled))
        let atFirstReminder = date(2026, 9, 8, 10)
        let plan = try ReminderPlan.make(slots: slots, enrolledAt: enrolled, studyEndDate: end,
                                         now: atFirstReminder, calendar: calendar)
        XCTAssertEqual(plan.count, 59)
        XCTAssertEqual(plan.first?.date, date(2026, 9, 8, 14))
        let evening = date(2026, 9, 8, 20)
        let next = try ReminderPlan.make(slots: slots, enrolledAt: enrolled, studyEndDate: end,
                                         now: evening, calendar: calendar)
        XCTAssertEqual(next.count, 57)
        XCTAssertTrue(next.allSatisfy { !calendar.isDate($0.date, inSameDayAs: evening) })
    }

    func testFiftySixDayEndIsExclusiveAndNeverSchedulesAfterStudy() throws {
        let enrolled = date(2026, 9, 8, 0)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 56, to: enrolled))
        let nearEnd = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: end))
        let plan = try ReminderPlan.make(slots: slots, enrolledAt: enrolled, studyEndDate: end,
                                         now: nearEnd, calendar: calendar)
        XCTAssertEqual(plan.count, 6)
        XCTAssertTrue(plan.allSatisfy { $0.date < end })
        XCTAssertTrue(try ReminderPlan.make(slots: slots, enrolledAt: enrolled, studyEndDate: end,
                                            now: end, calendar: calendar).isEmpty)
        XCTAssertTrue(try ReminderPlan.make(slots: slots, enrolledAt: enrolled, studyEndDate: end,
                                            now: end.addingTimeInterval(1), calendar: calendar).isEmpty)
    }

    func testSpringForwardPreservesThreePromptsAndTwentyLocalDays() throws {
        let now = date(2026, 3, 8, 0)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 56, to: now))
        var springSlots = slots
        springSlots[0].hour = 2
        springSlots[0].minute = 30
        let plan = try ReminderPlan.make(slots: springSlots, enrolledAt: now, studyEndDate: end,
                                         now: now, calendar: calendar)
        let firstDay = plan.filter { calendar.isDate($0.date, inSameDayAs: now) }
        XCTAssertEqual(firstDay.count, 3)
        XCTAssertEqual(plan.count, 60)
        XCTAssertEqual(calendar.component(.hour, from: try XCTUnwrap(firstDay.first).date), 3)
        XCTAssertEqual(calendar.component(.minute, from: try XCTUnwrap(firstDay.first).date), 0)
        XCTAssertEqual(Set(plan.map { calendar.startOfDay(for: $0.date) }).count, 20)
    }

    func testFallBackSchedulesRepeatedWallClockTimeOnlyOnce() throws {
        let now = date(2026, 11, 1, 0)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 56, to: now))
        var fallSlots = slots
        fallSlots[0].hour = 1
        fallSlots[0].minute = 30
        let plan = try ReminderPlan.make(slots: fallSlots, enrolledAt: now, studyEndDate: end,
                                         now: now, calendar: calendar)
        let morning = plan.filter { $0.slotID == "morning" && calendar.isDate($0.date, inSameDayAs: now) }
        XCTAssertEqual(morning.count, 1)
        XCTAssertEqual(morning.first?.date, ISO8601DateFormatter().date(from: "2026-11-01T05:30:00Z"))
        XCTAssertEqual(plan.count, 60)
    }

    func testStaleUnknownFutureDuplicateAndPostStudyRoutesBecomeOnDemand() throws {
        let enrolled = date(2026, 9, 8, 0)
        let now = date(2026, 9, 9, 12)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 56, to: enrolled))
        func eligible(_ route: ReminderRoute, completed: Set<String> = [], at time: Date? = nil) -> String? {
            route.eligibleSlotID(reminders: slots, completedSlotIDs: completed, enrolledAt: enrolled,
                                 studyEndDate: end, now: time ?? now, calendar: calendar)
        }
        let current = ReminderRoute(slotID: "morning", occurrenceDate: date(2026, 9, 9, 10))
        XCTAssertEqual(eligible(current), "morning")
        XCTAssertNil(eligible(current, completed: ["morning"]))
        XCTAssertNil(eligible(current, at: end))
        XCTAssertNil(eligible(ReminderRoute(slotID: "morning", occurrenceDate: date(2026, 9, 8, 10))))
        XCTAssertNil(eligible(ReminderRoute(slotID: "unknown", occurrenceDate: date(2026, 9, 9, 10))))
        XCTAssertNil(eligible(ReminderRoute(slotID: "afternoon", occurrenceDate: date(2026, 9, 9, 14))))
        XCTAssertNil(eligible(ReminderRoute(slotID: "morning", occurrenceDate: nil)))
        XCTAssertNil(eligible(ReminderRoute(slotID: nil, occurrenceDate: date(2026, 9, 9, 10))))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
