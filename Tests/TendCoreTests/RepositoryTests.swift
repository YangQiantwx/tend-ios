import Foundation
import XCTest
@testable import TendCore

final class RepositoryTests: XCTestCase {
    func testFreshStudyContainsNoFabricatedParticipationOrWearableData() throws {
        let now = Date(timeIntervalSince1970: 1_783_420_000)
        let data = StudyData.fresh(configuration: try loadConfiguration(), now: now)
        try data.validate()
        XCTAssertEqual(data.settings.participantID, "DEMO-001")
        XCTAssertEqual(data.settings.displayName, "")
        XCTAssertEqual(data.settings.enrolledAt, now)
        XCTAssertFalse(data.settings.onboardingComplete)
        XCTAssertFalse(data.settings.notificationsEnabled)
        XCTAssertTrue(data.checkIns.isEmpty)
        XCTAssertTrue(data.sessions.isEmpty)
        XCTAssertTrue(data.events.isEmpty)
        XCTAssertTrue(data.wearableDays.isEmpty)
    }

    func testRoundTripKeepsIdentifiersTimestampsChoicesAndMissingWearableValues() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONStudyRepository(url: directory.appendingPathComponent("nested/study.json"))
        XCTAssertNil(try repository.load())
        let fixture = try historyFixture()
        try repository.save(fixture)
        let loaded = try XCTUnwrap(repository.load())
        XCTAssertEqual(loaded.checkIns.first?.id, fixture.checkIns.first?.id)
        XCTAssertEqual(loaded.checkIns.first?.startedAt, fixture.checkIns.first?.startedAt)
        XCTAssertEqual(loaded.checkIns.first?.answers, fixture.checkIns.first?.answers)
        XCTAssertEqual(loaded.checkIns.first?.origin, .scheduled)
        XCTAssertEqual(loaded.checkIns.first?.slotID, "morning")
        XCTAssertEqual(loaded.sessions.first?.checkInID, fixture.checkIns.first?.id)
        XCTAssertEqual(loaded.sessions.first?.helpfulness, 4)
        XCTAssertEqual(loaded.sessions.first?.note, "A small pause helped.")
        XCTAssertEqual(loaded.sessions.first?.completionSource, "self_report")
        XCTAssertEqual(loaded.savedPracticeIDs, ["grounding"])
        XCTAssertNil(loaded.wearableDays.first?.steps)
        XCTAssertNil(loaded.wearableDays.first?.sleepHours)
        XCTAssertNil(loaded.wearableDays.first?.syncedAt)
        XCTAssertEqual(loaded.wearableDays.first?.source, "test-fixture")
        let json = try String(contentsOf: repository.url, encoding: .utf8)
        XCTAssertTrue(json.contains("Z\""), "Dates should be portable ISO 8601 timestamps.")
        XCTAssertTrue(json.contains("\n"), "Local exports should be human-readable.")
    }

    func testCorruptFileIsReportedAndPreserved() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let repository = JSONStudyRepository(url: directory.appendingPathComponent("study.json"))
        let malformed = Data("{\"schemaVersion\":1, broken".utf8)
        try malformed.write(to: repository.url)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try Data(contentsOf: repository.url), malformed)
    }

    func testInvalidSaveDoesNotOverwriteExistingStudy() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONStudyRepository(url: directory.appendingPathComponent("study.json"))
        var data = try historyFixture()
        try repository.save(data)
        let originalBytes = try Data(contentsOf: repository.url)
        data.checkIns[0].answers.pain = 99
        XCTAssertThrowsError(try repository.save(data))
        XCTAssertEqual(try Data(contentsOf: repository.url), originalBytes)
    }

    func testSemanticCorruptionAndUnsupportedSchemaAreRejected() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let repository = JSONStudyRepository(url: directory.appendingPathComponent("study.json"))
        var data = try historyFixture()
        data.schemaVersion = 9
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let bytes = try encoder.encode(data)
        try bytes.write(to: repository.url)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try Data(contentsOf: repository.url), bytes)
        data.schemaVersion = 1
        data.sessions[0].completionSource = "timer_inferred"
        XCTAssertThrowsError(try data.validate())
        data.sessions[0].completionSource = "self_report"
        data.sessions[0].checkInID = UUID()
        XCTAssertThrowsError(try data.validate())
    }

    func testOptionalFeedbackCanBeOmitted() throws {
        var data = try historyFixture()
        data.sessions[0].helpfulness = nil
        data.sessions[0].note = nil
        XCTAssertNoThrow(try data.validate())
        data.sessions[0].helpfulness = 0
        XCTAssertThrowsError(try data.validate())
    }

    func testSavedRecommendationWindowAndOlderRecords() throws {
        let original = try historyFixture()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let olderRecord = try decoder.decode(StudyData.self, from: encoder.encode(original))
        XCTAssertNil(olderRecord.savedRecommendations)

        var updated = olderRecord
        let checkIn = try XCTUnwrap(updated.checkIns.first)
        let savedAt = checkIn.completedAt.addingTimeInterval(60)
        let saved = SavedRecommendation(id: UUID(), checkInID: checkIn.id,
            practiceIDs: checkIn.recommendedPracticeIDs, savedAt: savedAt,
            expiresAt: checkIn.recommendationExpiresAt)
        XCTAssertTrue(checkIn.recommendationsAvailable(at: checkIn.completedAt.addingTimeInterval(3599)))
        XCTAssertFalse(checkIn.recommendationsAvailable(at: checkIn.recommendationExpiresAt))
        XCTAssertTrue(saved.isAvailable(at: checkIn.completedAt.addingTimeInterval(3599)))
        XCTAssertFalse(saved.isAvailable(at: saved.expiresAt))
        updated.savedRecommendations = [saved]
        XCTAssertNoThrow(try updated.validate())
        updated.savedRecommendations?[0].practiceIDs = ["grounding", "short-walk"]
        XCTAssertThrowsError(try updated.validate())
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("TendCoreTests-\(UUID().uuidString)")
    }

    private func historyFixture() throws -> StudyData {
        let configuration = try loadConfiguration()
        let now = Date(timeIntervalSince1970: 1_783_420_000)
        var data = StudyData.fresh(configuration: configuration, now: now)
        data.settings.onboardingComplete = true
        let checkIn = CheckInRecord(
            id: UUID(), participantID: "DEMO-001", startedAt: now, completedAt: now.addingTimeInterval(30),
            timezoneID: "America/New_York", origin: .scheduled, slotID: "morning",
            answers: EMAAnswers(distress: 3, willingness: 4, fatigue: 2, pain: 2,
                                physicalFunction: 4, availableTime: .fiveTo10),
            ruleVersion: configuration.ruleVersion, recommendedPracticeIDs: ["short-walk", "mindful-breathing"]
        )
        data.checkIns = [checkIn]
        data.sessions = [PracticeSession(
            id: UUID(), participantID: "DEMO-001", practiceID: "mindful-breathing", checkInID: checkIn.id,
            startedAt: now.addingTimeInterval(40), endedAt: now.addingTimeInterval(340),
            durationSeconds: 300, completed: true, helpfulness: 4,
            note: "A small pause helped.", completionSource: "self_report"
        )]
        data.events = [StudyEvent(id: UUID(), timestamp: now, kind: "check_in_opened",
                                 referenceID: checkIn.id.uuidString, details: ["origin": "scheduled"])]
        data.savedPracticeIDs = ["grounding"]
        data.wearableDays = [WearableDay(id: "fixture-only", date: now, steps: nil, activeMinutes: nil,
                                        sleepHours: nil, restingHeartRate: nil, syncedAt: nil, source: "test-fixture")]
        return data
    }
}
