import Foundation

enum PracticeCategory: String, Codable, CaseIterable, Sendable {
    case movement
    case mindfulness
}

struct Practice: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var category: PracticeCategory
    var durationSeconds: Int
    var symbol: String
    var steps: [String]
    var audioScript: String
    /// Short on-screen cue, kept with the provisional practice script.
    var playerCue: String? = nil
}

struct ReminderSlot: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var label: String
    var hour: Int
    var minute: Int

    func validate() throws {
        guard !id.isEmpty, !label.isEmpty, (0...23).contains(hour), (0...59).contains(minute) else {
            throw StudyValidationError.invalid("Reminder slots need a name and a valid local time.")
        }
    }
}

enum AvailableTime: String, Codable, CaseIterable, Sendable {
    case under5
    case fiveTo10
    case tenTo30
    case over30

    var label: String {
        switch self {
        case .under5: "Less than 5 min"
        case .fiveTo10: "5–10 min"
        case .tenTo30: "10–30 min"
        case .over30: "More than 30 min"
        }
    }

    /// Each suggested option must fit within this budget. Both remain optional.
    var maxMinutes: Int {
        switch self {
        case .under5: 4
        case .fiveTo10: 10
        case .tenTo30: 30
        case .over30: Int.max / 60
        }
    }
}

struct EMAAnswers: Codable, Equatable, Sendable {
    var distress: Int
    var willingness: Int
    var fatigue: Int
    var pain: Int
    var physicalFunction: Int
    var availableTime: AvailableTime

    func validate() throws {
        let scores = [distress, willingness, fatigue, pain, physicalFunction]
        guard scores.allSatisfy({ (1...5).contains($0) }) else {
            throw StudyValidationError.invalid("Answer each rating using a value from 1 to 5.")
        }
    }
}

enum StudyValidationError: Error, LocalizedError, Equatable {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        }
    }
}
