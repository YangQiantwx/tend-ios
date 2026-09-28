import Foundation

/// A deterministic, inspectable prototype. Wearable signals are deliberately absent
/// from this interface because the Demo pilot does not use them for delivery.
struct RuleEngine {
    let configuration: StudyConfiguration

    func recommend(for answers: EMAAnswers) throws -> [Practice] {
        try answers.validate()
        try configuration.validate()
        let thresholds = configuration.thresholds
        let lowWillingness = answers.willingness <= thresholds.willingnessLow
        let needsGentlerMovement = answers.pain >= thresholds.painHigh
            || answers.fatigue >= thresholds.fatigueHigh
            || answers.physicalFunction <= thresholds.physicalFunctionLow

        let movementIDs: [String]
        if lowWillingness {
            movementIDs = ["movement-break"]
        } else if needsGentlerMovement {
            movementIDs = ["chair-stretch", "movement-break"]
        } else {
            movementIDs = ["short-walk", "sit-to-stand", "movement-break"]
        }

        let mindfulnessIDs: [String]
        if lowWillingness {
            mindfulnessIDs = ["grounding"]
        } else if answers.distress >= thresholds.distressHigh {
            mindfulnessIDs = ["self-compassion", "grounding"]
        } else if answers.fatigue >= thresholds.fatigueHigh {
            mindfulnessIDs = ["body-scan", "grounding"]
        } else {
            mindfulnessIDs = ["mindful-breathing", "self-compassion", "grounding"]
        }

        let budgetSeconds = answers.availableTime.maxMinutes * 60
        return [
            try firstEligible(in: movementIDs, category: .movement, budgetSeconds: budgetSeconds),
            try firstEligible(in: mindfulnessIDs, category: .mindfulness, budgetSeconds: budgetSeconds)
        ]
    }

    private func firstEligible(in ids: [String], category: PracticeCategory, budgetSeconds: Int) throws -> Practice {
        for id in ids {
            if let practice = configuration.practices.first(where: {
                $0.id == id && $0.category == category && $0.durationSeconds <= budgetSeconds
            }) {
                return practice
            }
        }
        throw StudyValidationError.invalid("No \(category.rawValue) option fits the available time.")
    }
}
