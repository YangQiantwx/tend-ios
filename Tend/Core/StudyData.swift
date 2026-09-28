import Foundation

enum CheckInOrigin: String, Codable, Sendable {
    case scheduled
    case onDemand
}

struct CheckInRecord: Codable, Identifiable, Sendable {
    var id: UUID
    var participantID: String
    var startedAt: Date
    var completedAt: Date
    var timezoneID: String
    var origin: CheckInOrigin
    var slotID: String?
    var answers: EMAAnswers
    var ruleVersion: String
    var recommendedPracticeIDs: [String]

    /// Provisional demo rule: these options describe this check-in for one hour.
    var recommendationExpiresAt: Date { completedAt.addingTimeInterval(60 * 60) }
    func recommendationsAvailable(at date: Date) -> Bool { date < recommendationExpiresAt }
}

enum PracticeEntrySource: String, Codable, Sendable {
    case library
    case recommendation
    case repeated = "repeat"
}

struct PracticeSession: Codable, Identifiable, Sendable {
    var id: UUID
    var participantID: String
    var practiceID: String
    var checkInID: UUID?
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Double
    var completed: Bool
    var helpfulness: Int?
    var note: String?
    var completionSource: String
    var entrySource: PracticeEntrySource? = nil
    var previousSessionID: UUID? = nil
    var feedbackUpdatedAt: Date? = nil
    /// Optional demo reflection using the same 1–5 distress scale as the check-in.
    var postPracticeDistress: Int? = nil
    /// Fixed at the moment this rating is first saved; editing a note does not move it.
    var postPracticeDistressRecordedAt: Date? = nil

    /// Completion is durable before this optional, independently editable reflection.
    func updatingFeedback(helpfulness: Int?, note: String?, postPracticeDistress: Int? = nil,
                          allowPostDistress: Bool = false,
                          at date: Date = Date()) throws -> Self {
        guard completed else {
            throw StudyValidationError.invalid("Reflection is available after a completed practice.")
        }
        guard helpfulness.map({ (1...5).contains($0) }) ?? true else {
            throw StudyValidationError.invalid("Choose a helpfulness rating between 1 and 5, or leave it blank.")
        }
        guard !allowPostDistress || (postPracticeDistress.map({ (1...5).contains($0) }) ?? true) else {
            throw StudyValidationError.invalid("Choose a distress rating between 1 and 5, or leave it blank.")
        }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = self
        result.helpfulness = helpfulness
        result.note = trimmed?.isEmpty == false ? trimmed : nil
        if allowPostDistress {
            result.postPracticeDistress = postPracticeDistress
            result.postPracticeDistressRecordedAt = postPracticeDistress == nil
                ? nil : (self.postPracticeDistressRecordedAt ?? date)
        }
        result.feedbackUpdatedAt = date
        return result
    }
}

/// Two self-reported observations linked to one check-in and completed practice.
/// A pair describes timing; it does not establish that the practice caused a change.
struct PracticeDistressPair: Identifiable, Sendable {
    let sessionID: UUID
    let checkInID: UUID
    let practiceID: String
    let before: Int
    let after: Int
    let checkInCompletedAt: Date
    let recordedAt: Date

    var id: UUID { sessionID }
}

struct StudyEvent: Codable, Identifiable, Sendable {
    var id: UUID
    var timestamp: Date
    var kind: String
    var referenceID: String?
    var details: [String: String]
}

/// A recommendation set saved after one check-in. The one-hour window is a
/// prototype interaction rule, not a finalized study protocol.
struct SavedRecommendation: Codable, Identifiable, Sendable {
    var id: UUID
    var checkInID: UUID
    var practiceIDs: [String]
    var savedAt: Date
    var expiresAt: Date

    func isAvailable(at date: Date) -> Bool { date < expiresAt }
}

/// An absent sample is unknown, never a zero. Simulated samples retain an explicit source label.
struct WearableDay: Codable, Identifiable, Sendable {
    var id: String
    var date: Date
    var steps: Int?
    var activeMinutes: Int?
    var sleepHours: Double?
    var restingHeartRate: Int?
    var syncedAt: Date?
    var source: String
}

struct ParticipantSettings: Codable, Sendable {
    var participantID: String
    var displayName: String
    var enrolledAt: Date
    var onboardingComplete: Bool
    var reminders: [ReminderSlot]
    var notificationsEnabled: Bool
    var audioEnabled: Bool
}

struct StudyData: Codable, Sendable {
    var schemaVersion: Int
    var settings: ParticipantSettings
    var checkIns: [CheckInRecord]
    var sessions: [PracticeSession]
    var events: [StudyEvent]
    var savedPracticeIDs: [String]
    var wearableDays: [WearableDay]
    // Optional to keep records written by earlier prototype builds readable.
    var savedRecommendations: [SavedRecommendation]? = nil
    var supportRequests: [SupportRequest]? = nil
    var fitbitDemoConnection: FitbitDemoConnection? = nil

    var practiceDistressPairs: [PracticeDistressPair] {
        let checkInsByID = Dictionary(uniqueKeysWithValues: checkIns.map { ($0.id, $0) })
        return sessions.compactMap { session in
            guard session.completed, let after = session.postPracticeDistress,
                  let recordedAt = session.postPracticeDistressRecordedAt,
                  let checkInID = session.checkInID,
                  let checkIn = checkInsByID[checkInID] else { return nil }
            return PracticeDistressPair(sessionID: session.id, checkInID: checkInID,
                practiceID: session.practiceID, before: checkIn.answers.distress,
                after: after, checkInCompletedAt: checkIn.completedAt,
                recordedAt: recordedAt)
        }
        .sorted { $0.recordedAt > $1.recordedAt }
    }

    static func fresh(configuration: StudyConfiguration, now: Date = Date()) -> StudyData {
        StudyData(
            schemaVersion: 1,
            settings: ParticipantSettings(
                participantID: "DEMO-001", displayName: "", enrolledAt: now,
                onboardingComplete: false, reminders: configuration.prompts,
                notificationsEnabled: false, audioEnabled: true
            ),
            checkIns: [], sessions: [], events: [], savedPracticeIDs: [], wearableDays: []
        )
    }

    func validate() throws {
        guard schemaVersion == 1 else {
            throw StudyValidationError.invalid("This study data version is not supported.")
        }
        guard !settings.participantID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudyValidationError.invalid("Study data is missing the participant identifier.")
        }
        try StudyConfiguration.validatePrompts(settings.reminders)
        guard Set(checkIns.map(\.id)).count == checkIns.count,
              Set(sessions.map(\.id)).count == sessions.count,
              Set(events.map(\.id)).count == events.count,
              Set(wearableDays.map(\.id)).count == wearableDays.count,
              Set(savedPracticeIDs).count == savedPracticeIDs.count else {
            throw StudyValidationError.invalid("Study data contains duplicate record identifiers.")
        }
        for checkIn in checkIns {
            try checkIn.answers.validate()
            guard checkIn.participantID == settings.participantID,
                  checkIn.completedAt >= checkIn.startedAt,
                  TimeZone(identifier: checkIn.timezoneID) != nil,
                  !checkIn.ruleVersion.isEmpty,
                  checkIn.recommendedPracticeIDs.count == 2,
                  Set(checkIn.recommendedPracticeIDs).count == 2 else {
                throw StudyValidationError.invalid("A check-in record is incomplete or inconsistent.")
            }
            if checkIn.origin == .scheduled, checkIn.slotID?.isEmpty != false {
                throw StudyValidationError.invalid("Scheduled check-ins must identify their reminder slot.")
            }
        }
        let checkInIDs = Set(checkIns.map(\.id))
        let sessionIDs = Set(sessions.map(\.id))
        guard Set((savedRecommendations ?? []).map(\.id)).count == (savedRecommendations ?? []).count else {
            throw StudyValidationError.invalid("Saved recommendations contain duplicate identifiers.")
        }
        for saved in savedRecommendations ?? [] {
            guard let checkIn = checkIns.first(where: { $0.id == saved.checkInID }),
                  Set(saved.practiceIDs) == Set(checkIn.recommendedPracticeIDs),
                  saved.expiresAt > saved.savedAt else {
                throw StudyValidationError.invalid("A saved recommendation is incomplete or inconsistent.")
            }
        }
        for session in sessions {
            guard session.participantID == settings.participantID,
                  !session.practiceID.isEmpty,
                  session.endedAt >= session.startedAt,
                  session.durationSeconds.isFinite, session.durationSeconds >= 0,
                  session.completionSource == "self_report",
                  session.helpfulness.map({ (1...5).contains($0) }) ?? true,
                  session.postPracticeDistress.map({ (1...5).contains($0) }) ?? true,
                  (session.postPracticeDistress == nil || session.completed),
                  (session.postPracticeDistressRecordedAt == nil || session.postPracticeDistress != nil),
                  session.checkInID.map({ checkInIDs.contains($0) }) ?? true,
                  session.previousSessionID.map({ $0 != session.id && sessionIDs.contains($0) }) ?? true,
                  session.feedbackUpdatedAt == nil || session.completed else {
                throw StudyValidationError.invalid("A practice session is incomplete or inconsistent.")
            }
        }
        let requests = supportRequests ?? []
        guard Set(requests.map(\.id)).count == requests.count else {
            throw StudyValidationError.invalid("Support requests contain duplicate identifiers.")
        }
        for request in requests { try request.validate() }
        try fitbitDemoConnection?.validate()
        for sample in wearableDays {
            guard !sample.id.isEmpty, !sample.source.isEmpty,
                  sample.steps.map({ $0 >= 0 }) ?? true,
                  sample.activeMinutes.map({ (0...1440).contains($0) }) ?? true,
                  sample.sleepHours.map({ $0.isFinite && (0...24).contains($0) }) ?? true,
                  sample.restingHeartRate.map({ $0 > 0 }) ?? true else {
                throw StudyValidationError.invalid("A wearable sample contains an invalid value.")
            }
        }
    }
}
