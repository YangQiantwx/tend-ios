import Foundation

enum SupportDestination: String, Codable, CaseIterable, Sendable {
    case studyTeam
    case technicalSupport
}

enum SupportRequestStatus: String, Codable, Sendable {
    case draft
    case savedLocally
}

/// Local correspondence prepared by the participant. It has no delivery status.
struct SupportRequest: Codable, Identifiable, Sendable {
    var id: UUID
    var destination: SupportDestination
    var subject: String
    var message: String
    var createdAt: Date
    var updatedAt: Date
    var status: SupportRequestStatus

    static func prepared(id: UUID = UUID(), destination: SupportDestination,
                         subject: String, message: String, status: SupportRequestStatus,
                         createdAt: Date? = nil, now: Date = Date()) throws -> Self {
        let request = Self(id: id, destination: destination,
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt ?? now, updatedAt: now, status: status)
        try request.validate()
        return request
    }

    func validate() throws {
        guard updatedAt >= createdAt, subject.count <= 120, message.count <= 4000,
              !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
              !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudyValidationError.invalid("Add a subject or message. Keep the subject under 120 characters and the message under 4,000 characters.")
        }
        if status == .savedLocally && message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw StudyValidationError.invalid("Add a message before saving your request.")
        }
    }

    var shareText: String {
        let recipient = destination == .studyTeam ? "Study team" : "Technical support"
        return """
        Tend support request
        For: \(recipient)
        Subject: \(subject.isEmpty ? "General question" : subject)
        Prepared: \(updatedAt.ISO8601Format())
        Status: Saved on this device; Tend has not sent this request.

        \(message)
        """
    }
}
