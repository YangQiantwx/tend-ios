import Foundation

/// Illustrative thresholds only. Final delivery rules require study review.
struct RuleThresholds: Codable, Sendable {
    var painHigh: Int
    var fatigueHigh: Int
    var physicalFunctionLow: Int
    var willingnessLow: Int
    var distressHigh: Int
}

struct StudyConfiguration: Codable, Sendable {
    var schemaVersion: Int
    var ruleVersion: String
    var ruleStatus: String
    var studyDurationDays: Int
    var prompts: [ReminderSlot]
    var practices: [Practice]
    var thresholds: RuleThresholds
    var contentStatus: String? = nil
    var promptTimingStatus: String? = nil
    var protocolVersion: String? = nil
    var sourceDocuments: [String]? = nil

    static func load(from url: URL) throws -> StudyConfiguration {
        let configuration = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        try configuration.validate()
        return configuration
    }

    func validate() throws {
        guard schemaVersion == 1, !ruleVersion.isEmpty, !ruleStatus.isEmpty, studyDurationDays > 0 else {
            throw StudyValidationError.invalid("Study configuration is missing valid version or duration information.")
        }
        try Self.validatePrompts(prompts)
        let values = [thresholds.painHigh, thresholds.fatigueHigh, thresholds.physicalFunctionLow,
                      thresholds.willingnessLow, thresholds.distressHigh]
        guard values.allSatisfy({ (1...5).contains($0) }) else {
            throw StudyValidationError.invalid("Every delivery threshold must be between 1 and 5.")
        }
        guard Set(practices.map(\.id)).count == practices.count else {
            throw StudyValidationError.invalid("Practice identifiers must be unique.")
        }
        for practice in practices {
            guard !practice.id.isEmpty, !practice.title.isEmpty, !practice.subtitle.isEmpty,
                  !practice.symbol.isEmpty, practice.durationSeconds > 0,
                  !practice.steps.isEmpty, practice.steps.allSatisfy({ !$0.isEmpty }),
                  !practice.audioScript.isEmpty else {
                throw StudyValidationError.invalid("Each practice needs content and a positive duration.")
            }
        }
        let required: [PracticeCategory: [String]] = [
            .movement: ["short-walk", "chair-stretch", "movement-break", "sit-to-stand"],
            .mindfulness: ["mindful-breathing", "body-scan", "self-compassion", "grounding"]
        ]
        for (category, ids) in required {
            for id in ids {
                guard practices.contains(where: { $0.id == id && $0.category == category }) else {
                    throw StudyValidationError.invalid("Configuration is missing the required \(id) practice.")
                }
            }
        }
        for id in ["movement-break", "grounding"] {
            guard let practice = practices.first(where: { $0.id == id }), practice.durationSeconds <= 240 else {
                throw StudyValidationError.invalid("Brief fallback practices must fit in less than five minutes.")
            }
        }
    }

    static func validatePrompts(_ prompts: [ReminderSlot]) throws {
        try prompts.forEach { try $0.validate() }
        guard prompts.count == 3,
              Set(prompts.map(\.id)).count == 3,
              Set(prompts.map({ $0.hour * 60 + $0.minute })).count == 3 else {
            throw StudyValidationError.invalid("The study needs three distinct daily reminder times.")
        }
    }
}
