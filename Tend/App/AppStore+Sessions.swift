import Foundation

extension AppStore {
    @discardableResult
    func recordSession(_ session: PracticeSession) -> Bool {
        guard !data.sessions.contains(where: { $0.id == session.id }) else { return true }
        let saved = data.savedRecommendations ?? []
        let didSave = commit { value in
            value.sessions.append(session)
            var details = ["practiceID": session.practiceID, "completionSource": session.completionSource]
            if let source = session.entrySource { details["entrySource"] = source.rawValue }
            if let previous = session.previousSessionID { details["previousSessionID"] = previous.uuidString }
            value.events.append(event(session.completed ? "practice_completed" : "practice_ended_early",
                                      reference: session.id.uuidString, details: details))
        }
        if didSave, session.completed, dataMode.allowsSystemNotifications {
            for item in saved where item.checkInID == session.checkInID && remainingPractices(for: item).isEmpty {
                Task { await SavedRecommendationReminder.cancel(item.id) }
            }
        }
        return didSave
    }

    @discardableResult
    func updateSessionFeedback(sessionID: UUID, helpfulness: Int?, note: String?,
                               postPracticeDistress: Int?, allowPostDistress: Bool = false) -> Bool {
        guard let index = data.sessions.firstIndex(where: { $0.id == sessionID }) else {
            persistenceError = "This practice could not be found. Please reopen its record and try again."
            return false
        }
        do {
            let updated = try data.sessions[index].updatingFeedback(
                helpfulness: helpfulness, note: note, postPracticeDistress: postPracticeDistress,
                allowPostDistress: allowPostDistress)
            return commit { value in
                value.sessions[index] = updated
                value.events.append(event("practice_feedback_updated", reference: sessionID.uuidString,
                                          details: ["ratingProvided": String(helpfulness != nil),
                                                    "noteProvided": String(updated.note != nil),
                                                    "postDistressProvided": String(updated.postPracticeDistress != nil)]))
            }
        } catch { persistenceError = error.localizedDescription; return false }
    }

    @discardableResult
    func recordReminderOpened(_ route: ReminderRoute) -> Bool {
        guard !data.events.contains(where: { $0.kind == "reminder_opened" && $0.referenceID == route.id.uuidString }) else { return true }
        return commit { value in
            value.events.append(StudyEvent(id: UUID(), timestamp: route.openedAt ?? Date(), kind: "reminder_opened",
                referenceID: route.id.uuidString, details: ["slotID": route.slotID ?? "unknown",
                    "occurrenceDate": route.occurrenceDate?.ISO8601Format() ?? "unknown"]))
        }
    }
}
