import Foundation
import Observation

@MainActor @Observable
final class AppStore {
    private(set) var data: StudyData
    let configuration: StudyConfiguration
    let dataMode: AppDataMode
    private let repository: any StudyRepository
    private let directory: URL
    private let draftRepository: JSONDraftRepository
    private var draftStorageBlocked = false
    var persistenceError: String?
    var draftRecoveryMessage: String?
    var activeCheckIn: CheckInPresentation?
    var pendingCheckInRequest: CheckInRequest?
    var isPracticePresented = false
    private(set) var homeNavigationID = UUID()
    private(set) var savedDraft: CheckInDraft?
    var notificationsStatus = "Not enabled"

    init(configuration: StudyConfiguration, directory: URL, repository: (any StudyRepository)? = nil,
         dataMode: AppDataMode = .current) throws {
        self.configuration = configuration
        self.dataMode = dataMode
        self.directory = directory
        let studyRepository = repository ?? JSONStudyRepository(url: directory.appendingPathComponent("study-data.json"))
        self.repository = studyRepository
        draftRepository = JSONDraftRepository(url: directory.appendingPathComponent("check-in-draft.json"))
        data = try studyRepository.load() ?? StudyData.fresh(configuration: configuration)
        do {
            switch try draftRepository.load() {
            case .missing: break
            case .draft(let draft): savedDraft = draft
            case .quarantined:
                draftRecoveryMessage = "An unfinished check-in could not be read. Its original file has been kept for recovery. Your saved check-ins and practices are available, and you can begin a new check-in."
            }
        } catch {
            draftStorageBlocked = true
            draftRecoveryMessage = "Your saved records are available, but the unfinished check-in could not be opened or safely moved. Its file has been preserved. Please reopen Tend to try again. \(error.localizedDescription)"
        }
        if let draft = savedDraft, data.checkIns.contains(where: { $0.id == draft.id }) {
            savedDraft = nil
            try? draftRepository.remove()
        }
    }

    func returnToToday() {
        activeCheckIn = nil
        pendingCheckInRequest = nil
        isPracticePresented = false
        homeNavigationID = UUID()
    }

    func practice(id: String) -> Practice? { configuration.practices.first { $0.id == id } }

    var isDemoMode: Bool { dataMode == .demo }
    var usesSampleHistory: Bool {
        isDemoMode || data.settings.participantID == "UI-FIXTURE-ONLY"
    }

    var savedRecommendations: [SavedRecommendation] {
        let now = Date()
        return (data.savedRecommendations ?? [])
            .filter { saved in
                saved.isAvailable(at: now) && saved.practiceIDs.contains { practiceID in
                    !data.sessions.contains { $0.checkInID == saved.checkInID && $0.practiceID == practiceID && $0.completed }
                }
            }
            .sorted { $0.savedAt > $1.savedAt }
    }

    func remainingPractices(for saved: SavedRecommendation) -> [Practice] {
        saved.practiceIDs.compactMap { practiceID in
            guard !data.sessions.contains(where: { $0.checkInID == saved.checkInID && $0.practiceID == practiceID && $0.completed }) else {
                return nil
            }
            return practice(id: practiceID)
        }
    }

    var studyEndDate: Date {
        Calendar.current.date(byAdding: .day, value: configuration.studyDurationDays,
                              to: Calendar.current.startOfDay(for: data.settings.enrolledAt)) ?? data.settings.enrolledAt
    }

    var isStudyActive: Bool { Date() < studyEndDate }

    var todayCheckIns: [CheckInRecord] {
        data.checkIns.filter { Calendar.current.isDateInToday($0.completedAt) }
    }

    var completedSlotIDs: Set<String> {
        Set(todayCheckIns.filter { $0.origin == .scheduled }.compactMap(\.slotID))
    }

    func scheduledSlot(at now: Date = Date()) -> ReminderSlot? {
        let calendar = Calendar.current
        let completed = Set(data.checkIns.filter {
            $0.origin == .scheduled && calendar.isDate($0.completedAt, inSameDayAs: now)
        }.compactMap(\.slotID))
        return CheckInWindow.activeSlot(reminders: data.settings.reminders,
            completedSlotIDs: completed, enrolledAt: data.settings.enrolledAt,
            studyEndDate: studyEndDate, now: now, calendar: calendar,
            preview: .resolve(arguments: ProcessInfo.processInfo.arguments, dataMode: dataMode))
    }

    var nextReminder: ReminderSlot? {
        guard isStudyActive else { return nil }
        return data.settings.reminders.sorted { $0.hour * 60 + $0.minute < $1.hour * 60 + $1.minute }
            .first { !completedSlotIDs.contains($0.id) }
    }

    func startCheckIn(origin: CheckInOrigin, slotID: String? = nil) {
        guard activeCheckIn == nil else { return }
        if savedDraft != nil {
            pendingCheckInRequest = CheckInRequest(origin: origin, slotID: slotID)
        } else {
            beginNewCheckIn(origin: origin, slotID: slotID)
        }
    }

    func resumeSavedCheckIn() {
        guard activeCheckIn == nil, let savedDraft else { return }
        pendingCheckInRequest = nil
        activeCheckIn = CheckInPresentation(draft: savedDraft)
    }

    func replaceDraftAndStartCheckIn(request: CheckInRequest? = nil) {
        guard let request = request ?? pendingCheckInRequest else { return }
        beginNewCheckIn(origin: request.origin, slotID: request.slotID)
    }

    @discardableResult
    func discardSavedDraft() -> Bool {
        do {
            let id = savedDraft?.id
            try draftRepository.remove()
            savedDraft = nil
            if let id { _ = recordEvent(kind: "check_in_draft_discarded", referenceID: id.uuidString) }
            return true
        } catch { persistenceError = "Your draft could not be removed. Please try again. \(error.localizedDescription)"; return false }
    }

    private func beginNewCheckIn(origin: CheckInOrigin, slotID: String?) {
        let replacingID = savedDraft?.id
        let now = Date()
        let validSlot = slotID != nil && scheduledSlot(at: now)?.id == slotID
        let resolvedOrigin: CheckInOrigin = origin == .scheduled && validSlot ? .scheduled : .onDemand
        let draft = CheckInDraft(id: UUID(), startedAt: now, origin: resolvedOrigin,
                                slotID: resolvedOrigin == .scheduled ? slotID : nil)
        guard saveDraft(draft) else { return }
        _ = commit { value in
            if let replacingID { value.events.append(event("check_in_draft_discarded", reference: replacingID.uuidString)) }
            value.events.append(event("check_in_opened", reference: draft.id.uuidString,
                                      details: ["origin": resolvedOrigin.rawValue, "slotID": draft.slotID ?? ""]))
        }
        pendingCheckInRequest = nil
        activeCheckIn = CheckInPresentation(draft: draft)
    }

    @discardableResult
    func saveDraft(_ draft: CheckInDraft) -> Bool {
        do {
            guard !draftStorageBlocked else {
                throw StudyValidationError.invalid("The previous draft is preserved but could not be accessed safely. Please reopen Tend before starting another check-in.")
            }
            try draftRepository.save(draft)
            savedDraft = draft
            return true
        } catch { persistenceError = "Your answers could not be saved. Please try again. \(error.localizedDescription)"; return false }
    }

    func submitCheckIn(_ draft: CheckInDraft, completedAt now: Date = Date()) -> CheckInRecord? {
        if let existing = data.checkIns.first(where: { $0.id == draft.id }) { return existing }
        do {
            let answers = try draft.answers()
            let recommended = try RuleEngine(configuration: configuration).recommend(for: answers)
            let isSameDay = Calendar.current.isDate(draft.startedAt, inSameDayAs: now)
            // Retain answers from late or resumed drafts as extra check-ins. A scheduled
            // response must both start and finish within its original one-hour window.
            let validSlot = draft.slotID != nil
                && scheduledSlot(at: draft.startedAt)?.id == draft.slotID
                && scheduledSlot(at: now)?.id == draft.slotID
            let origin: CheckInOrigin = isSameDay && validSlot ? draft.origin : .onDemand
            let record = CheckInRecord(id: draft.id, participantID: data.settings.participantID,
                startedAt: draft.startedAt, completedAt: now, timezoneID: TimeZone.current.identifier,
                origin: origin, slotID: origin == .scheduled ? draft.slotID : nil, answers: answers,
                ruleVersion: configuration.ruleVersion, recommendedPracticeIDs: recommended.map(\.id))
            guard commit({ value in
                value.checkIns.append(record)
                value.events.append(event("check_in_completed", reference: record.id.uuidString,
                                          details: ["ruleVersion": configuration.ruleVersion, "origin": origin.rawValue]))
            }) else { return nil }
            savedDraft = nil
            try? draftRepository.remove()
            if record.origin == .scheduled { Task { await refreshNotificationStatus() } }
            return record
        } catch { persistenceError = error.localizedDescription; return nil }
    }

    @discardableResult
    func toggleSaved(_ practice: Practice) -> Bool {
        commit { value in
            let removing = value.savedPracticeIDs.contains(practice.id)
            value.savedPracticeIDs.removeAll { $0 == practice.id }
            if !removing { value.savedPracticeIDs.append(practice.id) }
            value.events.append(event(removing ? "practice_unsaved" : "practice_saved", reference: practice.id))
        }
    }

    @discardableResult
    func saveRecommendation(_ record: CheckInRecord) -> Bool {
        if (data.savedRecommendations ?? []).contains(where: { $0.checkInID == record.id }) { return true }
        let now = Date()
        let expiresAt = record.recommendationExpiresAt
        guard now < expiresAt else {
            persistenceError = "The one-hour demo window for these check-in options has ended. You can still explore practices from Today."
            return false
        }
        let saved = SavedRecommendation(id: UUID(), checkInID: record.id,
            practiceIDs: record.recommendedPracticeIDs, savedAt: now,
            expiresAt: expiresAt)
        guard commit({ value in
            value.savedRecommendations = (value.savedRecommendations ?? []) + [saved]
            value.events.append(event("recommendations_saved_for_later", reference: record.id.uuidString,
                                      details: ["expiresAt": saved.expiresAt.ISO8601Format(),
                                                "windowStatus": "prototype-one-hour"] ))
        }) else { return false }
        if data.settings.notificationsEnabled {
            Task { await refreshNotificationStatus() }
        }
        return true
    }

    @discardableResult
    func removeSavedRecommendation(_ saved: SavedRecommendation) -> Bool {
        guard commit({ value in
            value.savedRecommendations?.removeAll { $0.id == saved.id }
            value.events.append(event("saved_recommendation_removed", reference: saved.checkInID.uuidString))
        }) else { return false }
        if dataMode.allowsSystemNotifications { Task { await SavedRecommendationReminder.cancel(saved.id) } }
        return true
    }

    @discardableResult
    func recordEvent(kind: String, referenceID: String? = nil, details: [String: String] = [:]) -> Bool {
        commit { $0.events.append(event(kind, reference: referenceID, details: details)) }
    }

    @discardableResult
    func updateSettings(_ settings: ParticipantSettings) -> Bool {
        commit { $0.settings = settings }
    }

    func exportURL() throws -> URL {
        let url = directory.appendingPathComponent("tend-research-export.json")
        let now = Date()
        let export = StudyExport(exportedAt: now, isPrototype: true, configuration: configuration, data: data,
                                 analysis: .build(data: data, configuration: configuration, now: now))
        try export.write(to: url)
        return url
    }

    @discardableResult
    func loadSampleWearables() -> Bool {
        commit { value in
            let now = Date()
            value.wearableDays = (0..<7).compactMap { offset in
                guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: now) else { return nil }
                return WearableDay(id: "sample-\(offset)", date: date,
                    steps: offset == 2 ? nil : [3820, 4200, 0, 3100, 4800, 2900, 3600][offset],
                    activeMinutes: offset == 2 ? nil : 12 + offset,
                    sleepHours: offset == 0 || offset == 2 ? nil : 6.5 + Double(offset % 3) * 0.4,
                    restingHeartRate: offset == 2 ? nil : 64 + offset,
                    syncedAt: offset == 2 ? nil : date, source: "synthetic_demo")
            }
            value.events.append(event("sample_wearables_loaded", details: ["source": "synthetic_demo"]))
        }
    }

    func commit(_ update: (inout StudyData) -> Void) -> Bool {
        var candidate = data
        update(&candidate)
        do { try repository.save(candidate); data = candidate; return true }
        catch { persistenceError = "Your change could not be saved. Please try again. \(error.localizedDescription)"; return false }
    }

    func event(_ kind: String, reference: String? = nil, details: [String: String] = [:]) -> StudyEvent {
        StudyEvent(id: UUID(), timestamp: Date(), kind: kind, referenceID: reference, details: details)
    }
}

extension JSONEncoder {
    static var study: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
extension JSONDecoder {
    static var study: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
