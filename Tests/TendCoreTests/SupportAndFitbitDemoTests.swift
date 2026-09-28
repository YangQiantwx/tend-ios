import Foundation
import XCTest
@testable import TendCore

final class SupportAndFitbitDemoTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_500_000)

    func testLegacyDataWithoutSupportAndFitbitFieldsStillLoads() throws {
        let original = StudyData.fresh(configuration: try loadConfiguration(), now: now)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(original)) as? [String: Any])
        object.removeValue(forKey: "supportRequests")
        object.removeValue(forKey: "fitbitDemoConnection")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try decoder.decode(StudyData.self, from: JSONSerialization.data(withJSONObject: object))
        try loaded.validate()
        XCTAssertNil(loaded.supportRequests)
        XCTAssertNil(loaded.fitbitDemoConnection)
    }

    func testDraftToLocalRequestRetainsIdentityAndSurvivesReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONStudyRepository(url: directory.appendingPathComponent("study.json"))
        var study = StudyData.fresh(configuration: try loadConfiguration(), now: now)
        let draft = try SupportRequest.prepared(destination: .studyTeam, subject: "  Reminder question  ",
            message: "", status: .draft, now: now)
        study.supportRequests = [draft]
        try repository.save(study)
        study = try XCTUnwrap(repository.load())
        let loadedDraft = try XCTUnwrap(study.supportRequests?.first)
        XCTAssertEqual(loadedDraft.status, .draft)
        XCTAssertEqual(loadedDraft.subject, "Reminder question")
        let request = try SupportRequest.prepared(id: loadedDraft.id, destination: loadedDraft.destination,
            subject: loadedDraft.subject, message: "  Can I move my afternoon check-in?  ",
            status: .savedLocally, createdAt: loadedDraft.createdAt, now: now.addingTimeInterval(60))
        study.supportRequests = [request]
        try repository.save(study)
        let final = try XCTUnwrap(repository.load()?.supportRequests?.first)
        XCTAssertEqual(final.id, draft.id)
        XCTAssertEqual(final.createdAt, draft.createdAt)
        XCTAssertEqual(final.status, .savedLocally)
        XCTAssertEqual(final.message, "Can I move my afternoon check-in?")
        XCTAssertTrue(final.shareText.contains("Tend has not sent this request"))
        XCTAssertTrue(final.shareText.contains("For: Study team"))
    }

    func testEmptyAndOverlongRequestsAreRejected() throws {
        XCTAssertThrowsError(try SupportRequest.prepared(destination: .studyTeam, subject: " ", message: "\n", status: .draft))
        XCTAssertThrowsError(try SupportRequest.prepared(destination: .technicalSupport, subject: "Help", message: "", status: .savedLocally))
        XCTAssertThrowsError(try SupportRequest.prepared(destination: .studyTeam, subject: String(repeating: "a", count: 121), message: "Question", status: .savedLocally))
        XCTAssertThrowsError(try SupportRequest.prepared(destination: .studyTeam, subject: "Question", message: String(repeating: "a", count: 4001), status: .savedLocally))
    }

    func testInvalidSupportSavePreservesPreviouslySavedFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONStudyRepository(url: directory.appendingPathComponent("study.json"))
        var study = StudyData.fresh(configuration: try loadConfiguration(), now: now)
        let request = try SupportRequest.prepared(destination: .technicalSupport, subject: "Sound", message: "How do I enable audio?", status: .savedLocally, now: now)
        study.supportRequests = [request]
        try repository.save(study)
        let previous = try Data(contentsOf: repository.url)
        study.supportRequests = [request, request]
        XCTAssertThrowsError(try repository.save(study))
        XCTAssertEqual(try Data(contentsOf: repository.url), previous)
    }

    func testFitbitDemoSamplesAreExplicitAndPreserveMissingValues() throws {
        var study = StudyData.fresh(configuration: try loadConfiguration(), now: now)
        XCTAssertTrue(study.wearableDays.isEmpty)
        study.wearableDays = FitbitDemoConnection.sampleDays(at: now)
        study.fitbitDemoConnection = FitbitDemoConnection(isConnected: true, connectedAt: now, lastSyncedAt: now)
        try study.validate()
        XCTAssertEqual(study.wearableDays.count, 7)
        XCTAssertTrue(study.wearableDays.allSatisfy { $0.source == "synthetic_demo" })
        XCTAssertEqual(study.wearableDays.first?.steps, 3820)
        XCTAssertNil(study.wearableDays[2].steps)
        XCTAssertNil(study.wearableDays[2].syncedAt)
        XCTAssertNil(study.wearableDays.first?.sleepHours)
        XCTAssertTrue(study.checkIns.isEmpty)
        XCTAssertTrue(study.sessions.isEmpty)
        study.fitbitDemoConnection?.isConnected = false
        try study.validate()
        XCTAssertEqual(study.wearableDays.count, 7, "Disconnecting does not remove historical sample records.")
    }

    func testFitbitDemoStateRejectsLiveSourceAndImpossibleSyncTime() throws {
        var connection = FitbitDemoConnection(isConnected: true, connectedAt: now, lastSyncedAt: now.addingTimeInterval(-1))
        XCTAssertThrowsError(try connection.validate())
        connection.lastSyncedAt = now
        connection.source = "live_fitbit"
        XCTAssertThrowsError(try connection.validate())
    }
}
