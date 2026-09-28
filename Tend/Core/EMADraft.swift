import Foundation

struct CheckInDraft: Codable, Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    let origin: CheckInOrigin
    let slotID: String?
    var page: Int = 0
    var ratings: [String: Int] = [:]
    var availableTime: AvailableTime?

    func validate() throws {
        let keys: Set<String> = ["distress", "willingness", "fatigue", "pain", "physicalFunction"]
        guard (0...2).contains(page), ratings.allSatisfy({ keys.contains($0.key) && (1...5).contains($0.value) }),
              origin != .scheduled || slotID?.isEmpty == false else {
            throw StudyValidationError.invalid("The saved check-in draft is invalid. Its file has been preserved.")
        }
    }

    func answers() throws -> EMAAnswers {
        try validate()
        guard let distress = ratings["distress"], let willingness = ratings["willingness"],
              let fatigue = ratings["fatigue"], let pain = ratings["pain"],
              let function = ratings["physicalFunction"], let availableTime else {
            throw DraftError.incomplete
        }
        return EMAAnswers(distress: distress, willingness: willingness, fatigue: fatigue,
                          pain: pain, physicalFunction: function, availableTime: availableTime)
    }
    enum DraftError: LocalizedError {
        case incomplete
        var errorDescription: String? { "Please answer each question before continuing." }
    }
}
