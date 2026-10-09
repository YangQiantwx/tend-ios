import Foundation
import XCTest
@testable import TendCore

final class CheckInWindowTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }
    private let slots = [
        ReminderSlot(id: "morning", label: "Morning", hour: 10, minute: 0),
        ReminderSlot(id: "afternoon", label: "Afternoon", hour: 14, minute: 0),
        ReminderSlot(id: "evening", label: "Evening", hour: 18, minute: 0)
    ]

    func testOneHourWindowIncludesStartAndExcludesEnd() {
        let start = date(10)
        XCTAssertFalse(CheckInWindow.contains(start.addingTimeInterval(-1), startingAt: start))
        XCTAssertTrue(CheckInWindow.contains(start, startingAt: start))
        XCTAssertTrue(CheckInWindow.contains(start.addingTimeInterval(3599), startingAt: start))
        XCTAssertFalse(CheckInWindow.contains(start.addingTimeInterval(3600), startingAt: start))
        XCTAssertNil(active(at: start.addingTimeInterval(-1)))
        XCTAssertEqual(active(at: start)?.id, "morning")
        XCTAssertEqual(active(at: start.addingTimeInterval(3599))?.id, "morning")
        XCTAssertNil(active(at: date(11)))
    }

    func testAfternoonAndEveningUseLocalWallClock() {
        XCTAssertEqual(active(at: date(14))?.id, "afternoon")
        XCTAssertEqual(active(at: date(18))?.id, "evening")
        XCTAssertNil(active(at: date(13)))
        XCTAssertNil(active(at: date(19)))
    }

    func testCompletedSlotDoesNotReopenInItsWindow() {
        XCTAssertNil(active(at: date(10), completed: ["morning"]))
        XCTAssertEqual(active(at: date(14), completed: ["morning"])?.id, "afternoon")
    }

    func testPreviewOpenKeepsOneSlotAndClosesAfterCompletion() {
        let now = date(7)
        XCTAssertEqual(active(at: now, preview: .open)?.id, "morning")
        XCTAssertNil(active(at: now, completed: ["morning"], preview: .open))
        XCTAssertNil(active(at: now, completed: Set(slots.map(\.id)), preview: .open))
        XCTAssertNil(active(at: date(10), preview: .closed))
        XCTAssertNil(active(at: now))
    }

    func testPreviewWithoutMorningKeepsItsFirstSlotAfterCompletion() {
        let alternate = Array(slots.dropFirst())
        func candidate(completed: Set<String>) -> ReminderSlot? {
            CheckInWindow.activeSlot(reminders: alternate, completedSlotIDs: completed,
                enrolledAt: date(0), studyEndDate: date(23), now: date(7), calendar: calendar,
                preview: .open)
        }
        XCTAssertEqual(candidate(completed: [])?.id, "afternoon")
        XCTAssertNil(candidate(completed: ["afternoon"]))
    }

    func testOrdinaryDataIgnoresEveryPreviewFlag() {
        XCTAssertEqual(CheckInWindow.Preview.resolve(arguments: ["--demo-window-open"], dataMode: .standard), .live)
        XCTAssertEqual(CheckInWindow.Preview.resolve(arguments: ["--demo", "--demo-window-closed"], dataMode: .standard), .live)
        XCTAssertEqual(CheckInWindow.Preview.resolve(arguments: ["--demo"], dataMode: .demo), .live)
    }

    func testExplicitDemoAndUITestFlagsAndConflictingFlags() {
        #if DEBUG
        for mode: AppDataMode in [.demo, .uiTesting] {
            XCTAssertEqual(CheckInWindow.Preview.resolve(arguments: ["--demo-window-open"], dataMode: mode), .open)
            XCTAssertEqual(CheckInWindow.Preview.resolve(arguments: ["--demo-window-closed"], dataMode: mode), .closed)
            XCTAssertEqual(CheckInWindow.Preview.resolve(arguments: ["--demo-window-open", "--demo-window-closed"], dataMode: mode), .closed)
        }
        #endif
    }

    func testStudyStartAndEndCannotBeBypassedByPreview() {
        for preview: CheckInWindow.Preview in [.live, .open, .closed] {
            XCTAssertNil(CheckInWindow.activeSlot(reminders: slots, completedSlotIDs: [],
                enrolledAt: date(11), studyEndDate: date(23), now: date(10), calendar: calendar, preview: preview))
            XCTAssertNil(CheckInWindow.activeSlot(reminders: slots, completedSlotIDs: [],
                enrolledAt: date(0), studyEndDate: date(10), now: date(10), calendar: calendar, preview: preview))
        }
    }

    func testSpringForwardMatchesReminderSchedulingPolicy() throws {
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        let formatter = ISO8601DateFormatter()
        let start = try XCTUnwrap(formatter.date(from: "2026-03-08T07:00:00Z"))
        let localSlots = [ReminderSlot(id: "spring", label: "Spring", hour: 2, minute: 30)]
        func candidate(_ now: Date) -> ReminderSlot? {
            CheckInWindow.activeSlot(reminders: localSlots, completedSlotIDs: [],
                enrolledAt: start.addingTimeInterval(-86_400), studyEndDate: start.addingTimeInterval(86_400),
                now: now, calendar: ny)
        }
        XCTAssertEqual(candidate(start)?.id, "spring")
        XCTAssertEqual(candidate(start.addingTimeInterval(3599))?.id, "spring")
        XCTAssertNil(candidate(start.addingTimeInterval(3600)))
    }

    func testFallBackDoesNotCreateASecondWindow() throws {
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        let formatter = ISO8601DateFormatter()
        let first = try XCTUnwrap(formatter.date(from: "2026-11-01T05:30:00Z"))
        let second = try XCTUnwrap(formatter.date(from: "2026-11-01T06:30:00Z"))
        let localSlots = [ReminderSlot(id: "fall", label: "Fall", hour: 1, minute: 30)]
        func candidate(_ now: Date) -> ReminderSlot? {
            CheckInWindow.activeSlot(reminders: localSlots, completedSlotIDs: [],
                enrolledAt: first.addingTimeInterval(-86_400), studyEndDate: first.addingTimeInterval(86_400),
                now: now, calendar: ny)
        }
        XCTAssertEqual(candidate(first)?.id, "fall")
        XCTAssertNil(candidate(second))
    }

    private func date(_ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: hour))!
    }

    private func active(at now: Date, completed: Set<String> = [],
                        preview: CheckInWindow.Preview = .live) -> ReminderSlot? {
        CheckInWindow.activeSlot(reminders: slots, completedSlotIDs: completed,
            enrolledAt: date(0), studyEndDate: date(23), now: now, calendar: calendar, preview: preview)
    }
}
