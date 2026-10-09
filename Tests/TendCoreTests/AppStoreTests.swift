import Foundation
import Testing
@testable import TendCore

@MainActor
struct AppStoreTests {
    @Test func failedSettingsAndSessionSaveLeaveCommittedStateUnchanged() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FailingStudyRepository(url: directory.appendingPathComponent("study-data.json"))
        let store = try AppStore(configuration: loadConfiguration(), directory: directory,
                                 repository: repository, dataMode: .uiTesting)
        var settings = store.data.settings
        settings.displayName = "Saved name"
        #expect(store.updateSettings(settings))
        let original = try Data(contentsOf: repository.backing.url)
        repository.failWrites = true
        settings.displayName = "Unsaved name"
        #expect(!store.updateSettings(settings))
        #expect(store.data.settings.displayName == "Saved name")
        let session = completedSession(participantID: settings.participantID)
        #expect(!store.recordSession(session))
        #expect(store.data.sessions.isEmpty)
        #expect(try Data(contentsOf: repository.backing.url) == original)
        #expect(store.persistenceError != nil)
    }

    @Test func failedCheckInKeepsDraftAndSuccessfulRetryIsIdempotent() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FailingStudyRepository(url: directory.appendingPathComponent("study-data.json"))
        let configuration = try loadConfiguration()
        let store = try AppStore(configuration: configuration, directory: directory,
                                 repository: repository, dataMode: .uiTesting)
        let draft = completeDraft(origin: .onDemand, slotID: nil)
        #expect(store.saveDraft(draft))
        repository.failWrites = true
        #expect(store.submitCheckIn(draft) == nil)
        #expect(store.savedDraft?.id == draft.id)
        #expect(store.data.checkIns.isEmpty)
        repository.failWrites = false
        let record = try #require(store.submitCheckIn(draft))
        #expect(store.submitCheckIn(draft)?.id == record.id)
        #expect(store.data.checkIns.count == 1)
        #expect(store.savedDraft == nil)
        let restored = try AppStore(configuration: configuration, directory: directory, dataMode: .uiTesting)
        #expect(restored.data.checkIns.count == 1)
        #expect(restored.savedDraft == nil)
    }

    @Test func previousDayAndDuplicateScheduledDraftsBecomeExtraCheckIns() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AppStore(configuration: loadConfiguration(), directory: directory, dataMode: .uiTesting)
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
        let now = start.addingTimeInterval(15 * 60)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: start)!
        var settings = store.data.settings
        settings.enrolledAt = yesterday
        #expect(store.updateSettings(settings))
        let old = completeDraft(origin: .scheduled, slotID: "morning", startedAt: yesterday)
        #expect(store.submitCheckIn(old, completedAt: now)?.origin == .onDemand)
        #expect(store.completedSlotIDs.isEmpty)
        let first = completeDraft(origin: .scheduled, slotID: "morning", startedAt: start)
        #expect(store.submitCheckIn(first, completedAt: now)?.origin == .scheduled)
        let duplicate = completeDraft(origin: .scheduled, slotID: "morning", startedAt: start)
        #expect(store.submitCheckIn(duplicate, completedAt: now)?.origin == .onDemand)
        #expect(store.completedSlotIDs == ["morning"])
    }

    @Test func scheduledSubmissionRequiresOriginalWindowAndKeepsLateAnswers() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
        for (startedOffset, completedOffset, expected): (Double, Double, CheckInOrigin) in [
            (0, 3599, .scheduled), (60, 3600, .onDemand), (-1, 60, .onDemand),
            (60, 4 * 3600, .onDemand)
        ] {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let configuration = try loadConfiguration()
            let store = try AppStore(configuration: configuration, directory: directory, dataMode: .uiTesting)
            var settings = store.data.settings
            settings.enrolledAt = today.addingTimeInterval(-86_400)
            #expect(store.updateSettings(settings))
            let draft = completeDraft(origin: .scheduled, slotID: "morning",
                                      startedAt: start.addingTimeInterval(startedOffset))
            #expect(store.saveDraft(draft))
            let restored = try AppStore(configuration: configuration, directory: directory, dataMode: .uiTesting)
            let resumed = try #require(restored.savedDraft)
            let record = try #require(restored.submitCheckIn(resumed,
                completedAt: start.addingTimeInterval(completedOffset)))
            #expect(record.origin == expected)
            #expect(record.slotID == (expected == .scheduled ? "morning" : nil))
            #expect(record.id == draft.id)
            #expect(record.answers.distress == draft.ratings["distress"])
            #expect(record.answers.availableTime == draft.availableTime)
            #expect(restored.savedDraft == nil)
        }
    }

    @Test func newEveningDefaultDoesNotReplaceExistingReminderChoice() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = try loadConfiguration()
        #expect(configuration.prompts.first { $0.id == "evening" }?.hour == 18)
        let store = try AppStore(configuration: configuration, directory: directory, dataMode: .uiTesting)
        var settings = store.data.settings
        let eveningIndex = try #require(settings.reminders.firstIndex { $0.id == "evening" })
        settings.reminders[eveningIndex].hour = 19
        settings.reminders[eveningIndex].minute = 15
        #expect(store.updateSettings(settings))
        let restored = try AppStore(configuration: configuration, directory: directory, dataMode: .uiTesting)
        #expect(restored.data.settings.reminders[eveningIndex].hour == 19)
        #expect(restored.data.settings.reminders[eveningIndex].minute == 15)
    }

    @Test func savedRecommendationKeepsOriginalExpiryAndRemainingOptionAcrossReload() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = try loadConfiguration()
        let store = try AppStore(configuration: configuration, directory: directory, dataMode: .uiTesting)
        let record = try #require(store.submitCheckIn(completeDraft(origin: .onDemand, slotID: nil)))
        #expect(record.recommendedPracticeIDs.count == 2)
        #expect(store.saveRecommendation(record))
        let original = try #require(store.savedRecommendations.first)
        var session = completedSession(participantID: store.data.settings.participantID)
        session.practiceID = record.recommendedPracticeIDs[0]
        session.checkInID = record.id
        #expect(store.recordSession(session))
        #expect(store.saveRecommendation(record))
        let restored = try AppStore(configuration: configuration, directory: directory, dataMode: .uiTesting)
        let saved = try #require(restored.savedRecommendations.first)
        #expect(restored.savedRecommendations.count == 1)
        #expect(saved.id == original.id)
        #expect(saved.expiresAt.timeIntervalSince1970.rounded(.down)
            == record.recommendationExpiresAt.timeIntervalSince1970.rounded(.down))
        #expect(restored.remainingPractices(for: saved).map(\.id) == [record.recommendedPracticeIDs[1]])
        #expect(!saved.isAvailable(at: saved.expiresAt))
    }

    @Test func duplicateCompletionAndFeedbackUpdateKeepOneSessionAcrossReload() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = try loadConfiguration()
        let store = try AppStore(configuration: configuration, directory: directory, dataMode: .uiTesting)
        let session = completedSession(participantID: store.data.settings.participantID)
        #expect(store.recordSession(session))
        #expect(store.recordSession(session))
        #expect(store.updateSessionFeedback(sessionID: session.id, helpfulness: 4,
            note: "A useful pause", postPracticeDistress: nil))
        let restored = try AppStore(configuration: configuration, directory: directory, dataMode: .uiTesting)
        #expect(restored.data.sessions.count == 1)
        #expect(restored.data.sessions.first?.helpfulness == 4)
        #expect(restored.data.sessions.first?.endedAt.timeIntervalSince1970.rounded(.down)
            == session.endedAt.timeIntervalSince1970.rounded(.down))
    }

    @Test func exportFromFreshStoreCreatesDirectoryAndIncludesUsableSnapshot() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AppStore(configuration: loadConfiguration(), directory: directory, dataMode: .uiTesting)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        let url = try store.exportURL()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(StudyExport.self, from: Data(contentsOf: url))
        try exported.data.validate()
        #expect(exported.isPrototype)
        #expect(exported.configuration.practices.count == 8)
        #expect(exported.analysis.counts.includedScheduledCheckIns == 0)
        #expect(exported.data.checkIns.isEmpty)
    }

    @Test func demoReminderPreferencesPersistWithoutEnablingSystemNotifications() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = try loadConfiguration()
        let store = try AppStore(configuration: configuration, directory: directory, dataMode: .demo)
        var reminders = configuration.prompts
        reminders[0].minute = 15
        #expect(await store.updateReminders(reminders))
        await store.setNotificationsEnabled(true)
        await store.refreshNotificationStatus()
        #expect(!store.data.settings.notificationsEnabled)
        #expect(store.notificationsStatus == "System reminders are off in demo and test mode")
        let restored = try AppStore(configuration: configuration, directory: directory, dataMode: .demo)
        #expect(restored.data.settings.reminders[0].minute == 15)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("TendState-\(UUID().uuidString)")
    }

    private func completeDraft(origin: CheckInOrigin, slotID: String?, startedAt: Date = Date()) -> CheckInDraft {
        CheckInDraft(id: UUID(), startedAt: startedAt, origin: origin, slotID: slotID,
            page: 2, ratings: ["distress": 3, "willingness": 3, "fatigue": 2, "pain": 2, "physicalFunction": 4],
            availableTime: .under5)
    }

    private func completedSession(participantID: String) -> PracticeSession {
        let now = Date()
        return PracticeSession(id: UUID(), participantID: participantID, practiceID: "grounding", checkInID: nil,
            startedAt: now.addingTimeInterval(-60), endedAt: now, durationSeconds: 60, completed: true,
            helpfulness: nil, note: nil, completionSource: "self_report")
    }
}

private final class FailingStudyRepository: StudyRepository {
    let backing: JSONStudyRepository
    var failWrites = false
    init(url: URL) { backing = JSONStudyRepository(url: url) }
    func load() throws -> StudyData? { try backing.load() }
    func save(_ data: StudyData) throws {
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        try backing.save(data)
    }
}
