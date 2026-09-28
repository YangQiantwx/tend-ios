#if DEBUG
import Foundation

/// Explicit test-only fixtures, confined to the UITests directory by TendApp.
/// Never called by a normal launch, and never presented as participant history.
enum UITestScenario {
    static func prepare(directory: URL, configuration: StudyConfiguration, arguments: [String]) throws {
        if arguments.contains("--seed-journey") {
            let repository = JSONStudyRepository(url: directory.appendingPathComponent("study-data.json"))
            if try repository.load() == nil { try repository.save(journey(configuration: configuration)) }
        }
        if arguments.contains("--corrupt-draft") {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("intentional invalid UI-test draft".utf8)
                .write(to: directory.appendingPathComponent("check-in-draft.json"), options: .atomic)
        }
    }

    private static func journey(configuration: StudyConfiguration) -> StudyData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let enrolled = calendar.date(byAdding: .day, value: -12, to: today)!
        var data = StudyData.fresh(configuration: configuration, now: enrolled)
        data.settings.participantID = "UI-FIXTURE-ONLY"
        data.settings.displayName = "Preview"
        data.settings.onboardingComplete = true
        data.settings.audioEnabled = false
        let slots = configuration.prompts.sorted { $0.hour < $1.hour }
        for offset in 0..<13 {
            let day = calendar.date(byAdding: .day, value: offset, to: enrolled)!
            for (index, slot) in slots.enumerated() {
                guard !(offset % 4 == 1 && index == 1),
                      let completedAt = calendar.date(bySettingHour: slot.hour, minute: slot.minute, second: 45, of: day),
                      completedAt < Date() else { continue }
                let answers = EMAAnswers(distress: [2, 3, 2, 4, 1][(offset + index) % 5],
                    willingness: 4, fatigue: 2, pain: 2, physicalFunction: 4, availableTime: .tenTo30)
                let record = CheckInRecord(id: UUID(), participantID: data.settings.participantID,
                    startedAt: completedAt.addingTimeInterval(-40), completedAt: completedAt,
                    timezoneID: calendar.timeZone.identifier, origin: .scheduled, slotID: slot.id,
                    answers: answers, ruleVersion: configuration.ruleVersion,
                    recommendedPracticeIDs: ["short-walk", "mindful-breathing"])
                data.checkIns.append(record)
                if index == 0 || (index == 2 && offset % 3 == 0) {
                    let seconds = Double(180 + (offset % 3) * 60)
                    let end = completedAt.addingTimeInterval(seconds + 30)
                    guard end < Date() else { continue }
                    data.sessions.append(PracticeSession(id: UUID(), participantID: data.settings.participantID,
                        practiceID: offset % 2 == 0 ? "short-walk" : "mindful-breathing", checkInID: record.id,
                        startedAt: end.addingTimeInterval(-seconds), endedAt: end, durationSeconds: seconds,
                        completed: offset % 5 != 1, helpfulness: offset % 3 == 0 ? nil : 4,
                        note: nil, completionSource: "self_report"))
                }
            }
        }
        data.events = [StudyEvent(id: UUID(), timestamp: Date(), kind: "ui_test_fixture_loaded",
            referenceID: nil, details: ["source": "synthetic_ui_test_only", "purpose": "Charts and navigation QA"])]
        return data
    }
}
#endif
