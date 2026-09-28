import Foundation
import XCTest
@testable import TendCore

final class CompletedReminderTests: XCTestCase {
    func testCompletedFutureSlotIsRemovedOnlyForTodayWhileTomorrowKeepsThree() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 8)))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 56, to: now))
        let slots = try loadConfiguration().prompts
        let plan = try ReminderPlan.make(slots: slots, enrolledAt: now, studyEndDate: end,
            now: now, calendar: calendar, completedTodaySlotIDs: ["morning"])
        let today = plan.filter { calendar.isDate($0.date, inSameDayAs: now) }
        XCTAssertEqual(Set(today.map(\.slotID)), Set(["afternoon", "evening"]))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))
        XCTAssertEqual(plan.filter { calendar.isDate($0.date, inSameDayAs: tomorrow) }.count, 3)
        XCTAssertEqual(plan.count, 59)
    }
}
