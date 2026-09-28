import Foundation
import XCTest
@testable import TendCore

final class SessionRecoveryTests: XCTestCase {
    func testConfirmedCompletionSurvivesReloadBeforeOptionalFeedbackAndUpdatesSameRecord() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONStudyRepository(url: directory.appendingPathComponent("study.json"))
        var study = try fixture()
        let original = try XCTUnwrap(study.sessions.first)
        try repository.save(study)

        study = try XCTUnwrap(repository.load())
        XCTAssertTrue(try XCTUnwrap(study.sessions.first).completed)
        XCTAssertNil(study.sessions.first?.feedbackUpdatedAt)
        study.sessions[0] = try study.sessions[0].updatingFeedback(helpfulness: 4, note: "  A useful pause.  ",
            postPracticeDistress: 2, allowPostDistress: true,
            at: original.endedAt.addingTimeInterval(60))
        try repository.save(study)
        let reloaded = try XCTUnwrap(repository.load())
        let reflected = try XCTUnwrap(reloaded.sessions.first)
        XCTAssertEqual(reloaded.sessions.count, 1)
        XCTAssertEqual(reflected.id, original.id)
        XCTAssertEqual(reflected.endedAt, original.endedAt)
        XCTAssertEqual(reflected.durationSeconds, original.durationSeconds)
        XCTAssertEqual(reflected.entrySource, .library)
        XCTAssertEqual(reflected.helpfulness, 4)
        XCTAssertEqual(reflected.postPracticeDistress, 2)
        XCTAssertEqual(reflected.postPracticeDistressRecordedAt, original.endedAt.addingTimeInterval(60))
        XCTAssertEqual(reflected.note, "A useful pause.")
        XCTAssertNotNil(reflected.feedbackUpdatedAt)

        let cleared = try reflected.updatingFeedback(helpfulness: nil, note: " \n", at: original.endedAt.addingTimeInterval(90))
        XCTAssertTrue(cleared.completed)
        XCTAssertEqual(cleared.id, original.id)
        XCTAssertNil(cleared.helpfulness)
        XCTAssertEqual(cleared.postPracticeDistress, 2)
        XCTAssertEqual(cleared.postPracticeDistressRecordedAt, reflected.postPracticeDistressRecordedAt)
        XCTAssertNil(cleared.note)
        XCTAssertNotNil(cleared.feedbackUpdatedAt)

        let clearedImmediately = try reflected.updatingFeedback(helpfulness: 4, note: nil,
            postPracticeDistress: nil, allowPostDistress: true,
            at: original.endedAt.addingTimeInterval(90))
        XCTAssertNil(clearedImmediately.postPracticeDistress)
        XCTAssertNil(clearedImmediately.postPracticeDistressRecordedAt)
    }

    func testOldJSONWithoutEntryOrFeedbackMetadataStillLoads() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let study = try fixture()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(study)) as? [String: Any])
        var sessions = try XCTUnwrap(object["sessions"] as? [[String: Any]])
        sessions[0].removeValue(forKey: "entrySource")
        sessions[0].removeValue(forKey: "previousSessionID")
        sessions[0].removeValue(forKey: "feedbackUpdatedAt")
        sessions[0].removeValue(forKey: "postPracticeDistress")
        sessions[0].removeValue(forKey: "postPracticeDistressRecordedAt")
        object["sessions"] = sessions
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let legacy = try decoder.decode(StudyData.self, from: JSONSerialization.data(withJSONObject: object))
        try legacy.validate()
        XCTAssertNil(legacy.sessions.first?.entrySource)
        XCTAssertNil(legacy.sessions.first?.previousSessionID)
        XCTAssertNil(legacy.sessions.first?.feedbackUpdatedAt)
        XCTAssertNil(legacy.sessions.first?.postPracticeDistress)
        XCTAssertNil(legacy.sessions.first?.postPracticeDistressRecordedAt)
    }

    func testFeedbackRejectsInvalidRatingAndDoesNotConvertEarlyEndToCompletion() throws {
        var session = try XCTUnwrap(fixture().sessions.first)
        XCTAssertThrowsError(try session.updatingFeedback(helpfulness: 0, note: nil))
        XCTAssertThrowsError(try session.updatingFeedback(helpfulness: nil, note: nil,
            postPracticeDistress: 0, allowPostDistress: true))
        XCTAssertThrowsError(try session.updatingFeedback(helpfulness: nil, note: nil,
            postPracticeDistress: 6, allowPostDistress: true))
        session.completed = false
        XCTAssertThrowsError(try session.updatingFeedback(helpfulness: nil, note: nil))
        XCTAssertFalse(session.completed)
    }

    func testPairedDistressUsesOnlyActualLinkedCompletedPracticeRatings() throws {
        var study = try fixture()
        let now = study.settings.enrolledAt
        let checkIn = CheckInRecord(id: UUID(), participantID: study.settings.participantID,
            startedAt: now, completedAt: now.addingTimeInterval(20), timezoneID: "UTC",
            origin: .onDemand, slotID: nil,
            answers: EMAAnswers(distress: 4, willingness: 3, fatigue: 2, pain: 2,
                                physicalFunction: 3, availableTime: .fiveTo10),
            ruleVersion: "demo", recommendedPracticeIDs: ["grounding", "short-walk"])
        study.checkIns = [checkIn]
        study.sessions[0].checkInID = checkIn.id
        study.sessions[0].postPracticeDistress = 2
        study.sessions[0].postPracticeDistressRecordedAt = now.addingTimeInterval(90)
        study.sessions[0].feedbackUpdatedAt = now.addingTimeInterval(120)
        var unpaired = study.sessions[0]
        unpaired.id = UUID()
        unpaired.checkInID = nil
        study.sessions.append(unpaired)
        XCTAssertNoThrow(try study.validate())

        let pair = try XCTUnwrap(study.practiceDistressPairs.first)
        XCTAssertEqual(study.practiceDistressPairs.count, 1)
        XCTAssertEqual(pair.sessionID, study.sessions[0].id)
        XCTAssertEqual(pair.checkInID, checkIn.id)
        XCTAssertEqual(pair.before, 4)
        XCTAssertEqual(pair.after, 2)
        XCTAssertEqual(pair.recordedAt, now.addingTimeInterval(90))

        study.sessions[0].postPracticeDistressRecordedAt = nil
        XCTAssertTrue(study.practiceDistressPairs.isEmpty)
    }

    func testRepeatOriginRetainsValidPreviousSessionAndRejectsDanglingReference() throws {
        var study = try fixture()
        let previous = try XCTUnwrap(study.sessions.first)
        var repeated = previous
        repeated.id = UUID()
        repeated.entrySource = .repeated
        repeated.previousSessionID = previous.id
        study.sessions.append(repeated)
        XCTAssertNoThrow(try study.validate())
        study.sessions[1].previousSessionID = UUID()
        XCTAssertThrowsError(try study.validate())
    }

    private func fixture() throws -> StudyData {
        let now = Date(timeIntervalSince1970: 1_789_156_800)
        var study = StudyData.fresh(configuration: try loadConfiguration(), now: now)
        study.sessions = [PracticeSession(id: UUID(), participantID: study.settings.participantID,
            practiceID: "grounding", checkInID: nil, startedAt: now, endedAt: now.addingTimeInterval(60),
            durationSeconds: 60, completed: true, helpfulness: nil, note: nil,
            completionSource: "self_report", entrySource: .library)]
        return study
    }
}
