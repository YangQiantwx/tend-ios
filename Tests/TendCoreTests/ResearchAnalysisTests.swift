import Foundation
import XCTest
@testable import TendCore

final class ResearchAnalysisTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "UTC")!
        return value
    }

    func testPhaseBoundariesAndConfiguredEnd() throws {
        var config = try configuration()
        let data = StudyData.fresh(configuration: config, now: date(day: 1, hour: 8))
        let boundaries: [(Date, ResearchPhase, Int?)] = [
            (date(day: 1, hour: 7), .notStarted, nil),
            (date(day: 8, hour: 7), .historyInitialization, 7),
            (date(day: 8, hour: 8), .development, 8),
            (date(day: 43, hour: 7), .development, 42),
            (date(day: 43, hour: 8), .heldOut, 43),
            (date(day: 57, hour: 0), .complete, nil),
            (date(day: 57, hour: 8), .complete, nil)
        ]
        for (time, phase, day) in boundaries {
            let snapshot = build(data, config: config, now: time)
            XCTAssertEqual(snapshot.phase, phase)
            XCTAssertEqual(snapshot.studyDay, day)
        }
        config.studyDurationDays = 30
        XCTAssertEqual(build(data, config: config, now: date(day: 31, hour: 0)).phase, .complete)
        XCTAssertEqual(build(data, config: config).analysisEndDate, date(day: 31, hour: 0))
    }

    func testSevenFullDaysAreRequiredButNoMinimumSampleCountIsInvented() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(day: 1, hour: 8))
        let earlier = record(day: 2, score: 2)
        let warmup = record(day: 8, hour: 7, slot: "afternoon", score: 4)
        let ready = record(day: 8, hour: 8, score: 4)
        data.checkIns = [earlier, warmup, ready]
        let snapshot = build(data, config: config, now: date(day: 8, hour: 20))
        let initial = try label(warmup, in: snapshot)
        XCTAssertEqual(initial.status, .insufficientHistory)
        XCTAssertEqual(initial.historySampleCount, 1)
        XCTAssertNil(initial.median)
        let current = try label(ready, in: snapshot)
        XCTAssertEqual(current.historySampleCount, 2)
        XCTAssertEqual(current.median, 3)
        XCTAssertEqual(current.status, .elevated)
        data.checkIns = [earlier, ready]
        XCTAssertEqual(try label(ready, in: build(data, config: config)).median, 2)
    }

    func testWindowIsLeftInclusiveRightExclusiveAndEqualityIsNotElevated() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(day: 1))
        let tooOld = record(day: 1, hour: 9, slot: "morning", score: 5)
        let boundary = record(day: 1, hour: 10, slot: "afternoon", score: 2)
        let sameTime = record(day: 8, hour: 10, slot: "afternoon", score: 5)
        let target = record(day: 8, hour: 10, score: 2)
        data.checkIns = [target, tooOld, sameTime, boundary]
        let result = try label(target, in: build(data, config: config))
        XCTAssertEqual(result.historyRecordIDs, [boundary.id])
        XCTAssertEqual(result.historySampleCount, 1)
        XCTAssertEqual(result.median, 2)
        XCTAssertEqual(result.status, .notElevated)
    }

    func testTransitionKeepsDecisionThresholdWhenNextObservationMedianFalls() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(day: 1))
        let firstHistory = record(day: 7, score: 2)
        let secondHistory = record(day: 7, hour: 14, slot: "afternoon", score: 4)
        let current = record(day: 8, score: 2)
        let next = record(day: 8, hour: 14, slot: "afternoon", score: 3)
        var onDemand = record(day: 7, hour: 19, slot: "evening", score: 5)
        onDemand.origin = .onDemand
        let future = record(day: 9, score: 5)
        data.checkIns = [future, next, current, secondHistory, onDemand, firstHistory]
        let snapshot = build(data, config: config)
        XCTAssertEqual(try label(current, in: snapshot).median, 3)
        let nextLabel = try label(next, in: snapshot)
        XCTAssertEqual(nextLabel.median, 2)
        XCTAssertEqual(nextLabel.historyRecordIDs, [firstHistory.id, secondHistory.id, current.id])
        let pair = try XCTUnwrap(snapshot.transitions.first { $0.currentRecordID == current.id })
        // Each observation may describe its own recent history, but the forecast target
        // keeps the threshold that was available before the current decision.
        XCTAssertEqual(pair.status, .noElevation)
        XCTAssertEqual(pair.decisionReference?.decisionAt, current.completedAt)
        XCTAssertEqual(pair.decisionReference?.median, 3)
        XCTAssertEqual(pair.decisionReference?.historyRecordIDs, [firstHistory.id, secondHistory.id])
        XCTAssertEqual(pair.observedIntervalSeconds, 4 * 3600)
        XCTAssertEqual(Set(snapshot.excludedRecords.map(\.reason)), ["futureObservation", "onDemand"])
        let baseline = snapshot.labels.map(\.median)
        data.checkIns.removeAll { $0.id == future.id || $0.id == onDemand.id }
        XCTAssertEqual(build(data, config: config).labels.map(\.median), baseline)
    }

    func testTransitionKeepsDecisionThresholdWhenOldSamplesExpireBeforeNextEMA() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(day: 1))
        let expiring = record(day: 1, hour: 11, score: 1)
        let recent = record(day: 7, score: 5)
        let current = record(day: 8, score: 3)
        let next = record(day: 8, hour: 14, slot: "afternoon", score: 4)
        data.checkIns = [expiring, recent, current, next]

        let snapshot = build(data, config: config)
        XCTAssertEqual(try label(current, in: snapshot).median, 3)
        XCTAssertEqual(try label(next, in: snapshot).median, 4)
        XCTAssertEqual(try label(next, in: snapshot).status, .notElevated)
        let pair = try XCTUnwrap(snapshot.transitions.first { $0.currentRecordID == current.id })
        XCTAssertEqual(pair.status, .elevatedTransition)
        XCTAssertEqual(pair.decisionReference?.median, 3)
        XCTAssertEqual(pair.decisionReference?.historyRecordIDs, [expiring.id, recent.id])
    }

    func testMissingSlotsAreNotBridgedOrCountedAsNegativeAndDaysNeverCross() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(day: 1))
        let morning = record(day: 8, score: 2)
        let evening = record(day: 8, hour: 19, slot: "evening", score: 5)
        let nextMorning = record(day: 9, score: 5)
        data.checkIns = [record(day: 7, score: 3), morning, evening, nextMorning]
        let snapshot = build(data, config: config, now: date(day: 9, hour: 20))
        let beforeGap = try XCTUnwrap(snapshot.transitions.first { $0.currentRecordID == morning.id })
        let afterGap = try XCTUnwrap(snapshot.transitions.first { $0.nextRecordID == evening.id })
        XCTAssertEqual(beforeGap.status, .missingNext)
        XCTAssertEqual(afterGap.status, .missingCurrent)
        XCTAssertNil(beforeGap.status.transitionOccurred)
        XCTAssertFalse(snapshot.transitions.contains { $0.currentRecordID == morning.id && $0.nextRecordID == evening.id })
        XCTAssertFalse(snapshot.transitions.contains { $0.currentRecordID == evening.id && $0.nextRecordID == nextMorning.id })
        XCTAssertEqual(snapshot.counts.evaluableTransitions, 0)
    }

    func testUnknownHistoryAndPendingAreDistinctFromNegative() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(day: 1))
        let emptyWindow = record(day: 8, score: 1)
        let second = record(day: 8, hour: 14, slot: "afternoon", score: 1)
        data.checkIns = [emptyWindow, second]
        let snapshot = build(data, config: config, now: date(day: 8, hour: 15))
        XCTAssertEqual(try label(emptyWindow, in: snapshot).status, .noHistorySamples)
        let firstPair = try XCTUnwrap(snapshot.transitions.first { $0.currentRecordID == emptyWindow.id })
        XCTAssertEqual(firstPair.status, .unknownLabel)
        let pending = try XCTUnwrap(snapshot.transitions.first { $0.currentRecordID == second.id })
        XCTAssertEqual(pending.status, .pending)
        XCTAssertNil(pending.status.transitionOccurred)
    }

    func testNonChronologicalSlotsAndAlreadyElevatedCurrentAreNotNegative() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(day: 1))
        let current = record(day: 8, hour: 15, score: 5)
        let next = record(day: 8, hour: 14, slot: "afternoon", score: 1)
        data.checkIns = [record(day: 7, score: 2), current, next]
        var snapshot = build(data, config: config)
        XCTAssertEqual(snapshot.transitions.first { $0.currentRecordID == current.id }?.status, .nonChronological)
        data.checkIns[1].completedAt = date(day: 8, hour: 10)
        data.checkIns[1].startedAt = data.checkIns[1].completedAt.addingTimeInterval(-30)
        snapshot = build(data, config: config)
        let pair = try XCTUnwrap(snapshot.transitions.first { $0.currentRecordID == current.id })
        XCTAssertEqual(pair.status, .currentAlreadyElevated)
        XCTAssertNil(pair.status.transitionOccurred)
    }

    func testKnownNonElevatedPairIsTheOnlyNegativeOutcome() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(day: 1))
        let current = record(day: 8, score: 2)
        let next = record(day: 8, hour: 14, slot: "afternoon", score: 2)
        data.checkIns = [record(day: 7, score: 3), current, next]
        let snapshot = build(data, config: config)
        XCTAssertEqual(snapshot.transitions.first { $0.currentRecordID == current.id }?.status.transitionOccurred, false)
        XCTAssertEqual(snapshot.counts.evaluableTransitions, 1)
        XCTAssertEqual(snapshot.counts.elevatedTransitions, 0)
    }

    func testDuplicateSelectionIsDeterministicAndUnknownSlotsAreExcluded() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(day: 1))
        let early = record(day: 7, hour: 10, score: 2)
        let duplicate = record(day: 7, hour: 11, score: 5)
        let unknown = record(day: 7, hour: 12, slot: "retired-slot", score: 5)
        let current = record(day: 8, score: 2)
        data.checkIns = [duplicate, unknown, current, early]
        let snapshot = build(data, config: config)
        XCTAssertEqual(snapshot.includedRecordIDs, [early.id, current.id])
        XCTAssertEqual(try label(current, in: snapshot).median, 2)
        XCTAssertEqual(Set(snapshot.excludedRecords.map(\.reason)), ["duplicateDayAndSlot", "unknownReminderSlot"])
    }

    func testSnapshotRoundTripsWithExplicitSourceConflictAndSortedSlots() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(day: 1))
        data.settings.reminders.reverse()
        let snapshot = build(data, config: config)
        let decoded = try JSONDecoder().decode(ResearchAnalysisSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded.sourceVersion, "demo-analysis-v1")
        XCTAssertTrue(decoded.sourceParagraphs.isEmpty)
        XCTAssertTrue(decoded.sourceConflict.contains("Demo schedule"))
        XCTAssertTrue(decoded.sourceConflict.contains("weeks 2–6"))
        XCTAssertEqual(decoded.orderedSlots.map(\.id), ["morning", "afternoon", "evening"])
        XCTAssertEqual(decoded.timezoneID, "GMT")
        XCTAssertEqual(decoded.labels.count, 0)
    }

    func testTransitionReferenceRoundTripsAndLegacySnapshotHasNoInventedReference() throws {
        let config = try configuration()
        var data = StudyData.fresh(configuration: config, now: date(day: 1))
        let earlier = record(day: 7, score: 3)
        let current = record(day: 8, score: 2)
        let next = record(day: 8, hour: 14, slot: "afternoon", score: 4)
        data.checkIns = [earlier, current, next]
        let original = try XCTUnwrap(build(data, config: config).transitions.first {
            $0.currentRecordID == current.id
        })
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ResearchTransition.self, from: encoded)
        XCTAssertEqual(decoded.decisionReference?.historyRecordIDs, [earlier.id])
        XCTAssertEqual(decoded.decisionReference?.historyWindowStart, date(day: 1, hour: 10))
        XCTAssertEqual(decoded.decisionReference?.median, 3)

        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy.removeValue(forKey: "decisionReference")
        let migrated = try JSONDecoder().decode(ResearchTransition.self,
            from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(migrated.decisionReference)
        XCTAssertEqual(migrated.status, original.status)
    }

    func testProtocolDevelopmentAndHeldOutOpportunityCounts() throws {
        let config = try configuration()
        let data = StudyData.fresh(configuration: config, now: date(day: 1))
        let snapshot = build(data, config: config, now: date(day: 57))
        XCTAssertEqual(snapshot.transitions.filter { $0.phase == .historyInitialization }.count, 14)
        XCTAssertEqual(snapshot.transitions.filter { $0.phase == .development }.count, 70)
        XCTAssertEqual(snapshot.transitions.filter { $0.phase == .heldOut }.count, 28)
        XCTAssertTrue(snapshot.transitions.allSatisfy { $0.nextScheduledAt < snapshot.analysisEndDate })
        XCTAssertEqual(snapshot.counts.evaluableTransitions, 0)
        XCTAssertEqual(snapshot.counts.elevatedTransitions, 0)
    }

    func testCalendarDayHistoryHandlesDaylightSavingChange() throws {
        let config = try configuration()
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = TimeZone(identifier: "America/New_York")!
        let enrollment = localCalendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 10))!
        var data = StudyData.fresh(configuration: config, now: enrollment)
        let targetTime = localCalendar.date(byAdding: .day, value: 7, to: enrollment)!
        var history = record(day: 1, score: 2)
        history.startedAt = enrollment
        history.completedAt = enrollment
        var target = record(day: 8, score: 3)
        target.startedAt = targetTime
        target.completedAt = targetTime
        data.checkIns = [history, target]
        let snapshot = ResearchAnalysisSnapshot.build(data: data, configuration: config, now: targetTime, calendar: localCalendar)
        XCTAssertEqual(targetTime.timeIntervalSince(enrollment), 167 * 3600)
        XCTAssertEqual(try label(target, in: snapshot).historyWindowStart, enrollment)
        XCTAssertEqual(try label(target, in: snapshot).status, .elevated)
        XCTAssertEqual(snapshot.phase, .development)
    }

    private func build(_ data: StudyData, config: StudyConfiguration, now: Date? = nil) -> ResearchAnalysisSnapshot {
        .build(data: data, configuration: config, now: now ?? date(day: 8, hour: 20), calendar: calendar)
    }

    private func label(_ record: CheckInRecord, in snapshot: ResearchAnalysisSnapshot) throws -> ResearchDistressLabel {
        try XCTUnwrap(snapshot.labels.first { $0.recordID == record.id })
    }

    private func record(day: Int, hour: Int = 10, slot: String = "morning", score: Int) -> CheckInRecord {
        let completed = date(day: day, hour: hour)
        return CheckInRecord(id: UUID(), participantID: "DEMO-001", startedAt: completed.addingTimeInterval(-30),
            completedAt: completed, timezoneID: calendar.timeZone.identifier, origin: .scheduled, slotID: slot,
            answers: EMAAnswers(distress: score, willingness: 3, fatigue: 2, pain: 2,
                                physicalFunction: 4, availableTime: .fiveTo10),
            ruleVersion: "test", recommendedPracticeIDs: ["short-walk", "mindful-breathing"])
    }

    private func date(day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    private func configuration() throws -> StudyConfiguration {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try StudyConfiguration.load(from: root.appendingPathComponent("Tend/Resources/study-config.json"))
    }
}
