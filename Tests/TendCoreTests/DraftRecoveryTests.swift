import Foundation
import XCTest
@testable import TendCore

final class DraftRecoveryTests: XCTestCase {
    func testMalformedDraftIsPreservedWithoutAffectingCommittedStudyAndNewDraftCanBeSaved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let studyRepository = JSONStudyRepository(url: directory.appendingPathComponent("study.json"))
        try studyRepository.save(StudyData.fresh(configuration: loadConfiguration()))
        let studyBytes = try Data(contentsOf: studyRepository.url)
        let repository = JSONDraftRepository(url: directory.appendingPathComponent("draft.json"))
        let original = Data("{ broken JSON but preserve me".utf8)
        try original.write(to: repository.url)

        guard case .quarantined(let recoveryURL) = try repository.load() else { return XCTFail("Expected a recoverable draft") }
        XCTAssertEqual(try Data(contentsOf: recoveryURL), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.url.path))
        XCTAssertEqual(try Data(contentsOf: studyRepository.url), studyBytes)
        XCTAssertNotNil(try studyRepository.load())

        var draft = CheckInDraft(id: UUID(), startedAt: Date(timeIntervalSince1970: 1_789_156_800), origin: .onDemand, slotID: nil)
        draft.ratings["distress"] = 3
        try repository.save(draft)
        guard case .draft(let restored) = try repository.load() else { return XCTFail("Expected the fresh draft") }
        XCTAssertEqual(restored, draft)
        XCTAssertEqual(try Data(contentsOf: recoveryURL), original)
    }

    func testSemanticallyInvalidDraftIsAlsoQuarantinedWithoutNormalizingAnswers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let repository = JSONDraftRepository(url: directory.appendingPathComponent("draft.json"))
        var draft = CheckInDraft(id: UUID(), startedAt: Date(), origin: .onDemand, slotID: nil)
        draft.page = 99
        draft.ratings["distress"] = 6
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let bytes = try encoder.encode(draft)
        try bytes.write(to: repository.url)
        guard case .quarantined(let recoveryURL) = try repository.load() else { return XCTFail("Invalid answers must not reach the questionnaire") }
        XCTAssertEqual(try Data(contentsOf: recoveryURL), bytes)
    }
}
