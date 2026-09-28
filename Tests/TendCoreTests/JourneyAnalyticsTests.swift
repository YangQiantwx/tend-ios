import XCTest
@testable import TendCore

final class JourneyAnalyticsTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/New_York")!
        return value
    }
    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }
    private func configuration() throws -> StudyConfiguration {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(StudyConfiguration.self, from: Data(contentsOf: root.appendingPathComponent("Tend/Resources/study-config.json")))
    }
    private func record(at time: Date, origin: CheckInOrigin, slot: String? = nil) -> CheckInRecord {
        CheckInRecord(id: UUID(), participantID: "DEMO-001", startedAt: time.addingTimeInterval(-30), completedAt: time,
            timezoneID: calendar.timeZone.identifier, origin: origin, slotID: slot,
            answers: EMAAnswers(distress: 2, willingness: 4, fatigue: 3, pain: 1, physicalFunction: 5, availableTime: .fiveTo10),
            ruleVersion: "test", recommendedPracticeIDs: ["movement-break", "mindful-breathing"])
    }

    func testDailyCountsDeduplicateSlotsAndKeepOnDemandSeparate() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(8))
        data.checkIns = [record(at: date(9, hour: 10), origin: .scheduled, slot: "morning"),
                        record(at: date(9, hour: 11), origin: .scheduled, slot: "morning"),
                        record(at: date(9), origin: .onDemand), record(at: date(8), origin: .scheduled, slot: "morning")]
        let analytics = JourneyAnalytics(data: data, configuration: config, now: date(9, hour: 20), calendar: calendar)
        XCTAssertEqual(analytics.day(date(9)).scheduledCount, 1)
        XCTAssertEqual(analytics.day(date(9)).onDemandCount, 1)
        XCTAssertEqual(analytics.day(date(9)).ratingCount, 3)
        XCTAssertEqual(analytics.day(date(8)).scheduledCount, 1)
    }

    func testEnrollmentFutureAndStudyEndAreDistinctFromEmptyStudyDays() throws {
        var config = try configuration()
        config.studyDurationDays = 3
        let data = StudyData.fresh(configuration: config, now: date(8))
        let analytics = JourneyAnalytics(data: data, configuration: config, now: date(12), calendar: calendar)
        XCTAssertEqual(analytics.day(date(7)).status, .beforeEnrollment)
        XCTAssertEqual(analytics.day(date(9)).status, .active)
        XCTAssertFalse(analytics.day(date(9)).hasRecords)
        XCTAssertEqual(analytics.day(date(11)).status, .afterStudy)
        XCTAssertEqual(analytics.day(date(13)).status, .future)
    }

    func testPracticeTotalsUseActiveSecondsAndExcludeEarlyEndsFromCompletedMinutes() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(8))
        func session(_ practice: String, seconds: Double, complete: Bool) -> PracticeSession {
            PracticeSession(id: UUID(), participantID: "DEMO-001", practiceID: practice, checkInID: nil,
                startedAt: date(9).addingTimeInterval(-600), endedAt: date(9), durationSeconds: seconds,
                completed: complete, helpfulness: nil, note: nil, completionSource: "self_report")
        }
        data.sessions = [session("movement-break", seconds: 47, complete: true),
                         session("mindful-breathing", seconds: 125, complete: true),
                         session("mindful-breathing", seconds: 28, complete: false)]
        let day = JourneyAnalytics(data: data, configuration: config, now: date(9, hour: 20), calendar: calendar).day(date(9))
        XCTAssertEqual(day.movementSeconds, 47)
        XCTAssertEqual(day.mindfulnessSeconds, 125)
        XCTAssertEqual(day.completedSeconds, 172)
        XCTAssertEqual(day.endedEarlySeconds, 28)
        XCTAssertEqual(day.completedPracticeCount, 2)
        XCTAssertEqual(day.endedEarlyCount, 1)
    }

    func testRangesAreCalendarDaysAndNeverBackfillRatingsOrIncludeFutureRecords() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(8))
        data.checkIns = [record(at: date(9), origin: .onDemand), record(at: date(10), origin: .onDemand)]
        let analytics = JourneyAnalytics(data: data, configuration: config, now: date(9, hour: 20), calendar: calendar)
        let week = analytics.days(in: .week)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(analytics.days(in: .fourWeeks).count, 28)
        XCTAssertEqual(week.reduce(0) { $0 + $1.ratingCount }, 1)
        XCTAssertEqual(week.last?.date, calendar.startOfDay(for: date(9)))
        XCTAssertEqual(analytics.day(date(10)).ratingCount, 0)
    }

    func testRatingsKeepOriginalDirectionAndEachConstructSeparate() {
        let answers = record(at: date(9), origin: .onDemand).answers
        XCTAssertEqual(JourneyRating.physicalFunction.value(in: answers), 5)
        XCTAssertEqual(JourneyRating.pain.value(in: answers), 1)
        XCTAssertEqual(JourneyRating.willingness.value(in: answers), 4)
    }

    func testRemovedPracticeContentDoesNotLoseHistoricalMinutes() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(8))
        data.sessions = [PracticeSession(id: UUID(), participantID: "DEMO-001", practiceID: "retired-content", checkInID: nil,
            startedAt: date(9).addingTimeInterval(-100), endedAt: date(9), durationSeconds: 70,
            completed: true, helpfulness: nil, note: nil, completionSource: "self_report")]
        let day = JourneyAnalytics(data: data, configuration: config, now: date(9, hour: 20), calendar: calendar).day(date(9))
        XCTAssertEqual(day.completedSeconds, 70)
        XCTAssertEqual(day.unclassifiedSeconds, 70)
        XCTAssertEqual(day.movementSeconds + day.mindfulnessSeconds, 0)
    }
}
