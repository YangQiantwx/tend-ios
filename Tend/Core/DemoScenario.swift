import Foundation

/// Illustrative history relative to the preparation date. Today remains free for a walkthrough.
enum DemoScenario {
    static func prepare(directory: URL, configuration: StudyConfiguration, now: Date = Date()) throws {
        let repository = JSONStudyRepository(url: directory.appendingPathComponent("study-data.json"))
        guard try repository.load() == nil else { return }
        try repository.save(history(configuration: configuration, now: now))
    }

    static func history(configuration: StudyConfiguration, now: Date = Date(),
                        calendar: Calendar = .current) -> StudyData {
        let today = calendar.startOfDay(for: now)
        let enrolled = calendar.date(byAdding: .day, value: -27, to: today) ?? today
        var data = StudyData.fresh(configuration: configuration, now: enrolled)
        data.settings.participantID = "DEMO-SAMPLE-ONLY"
        data.settings.displayName = "Preview"
        data.settings.onboardingComplete = true
        let slots = configuration.prompts.sorted { $0.hour * 60 + $0.minute < $1.hour * 60 + $1.minute }
        for offset in 0..<27 {
            guard offset % 7 != 4,
                  let day = calendar.date(byAdding: .day, value: offset, to: enrolled) else { continue }
            for (index, slot) in slots.enumerated() {
                guard !(offset % 4 == 1 && index == 1),
                      let completedAt = calendar.date(bySettingHour: slot.hour, minute: slot.minute,
                                                       second: 45, of: day), completedAt < now else { continue }
                let answers = EMAAnswers(distress: [2, 3, 2, 4, 1][(offset + index) % 5],
                    willingness: 4, fatigue: 2, pain: 2, physicalFunction: 4, availableTime: .tenTo30)
                let record = CheckInRecord(id: UUID(), participantID: data.settings.participantID,
                    startedAt: completedAt.addingTimeInterval(-40), completedAt: completedAt,
                    timezoneID: calendar.timeZone.identifier, origin: .scheduled, slotID: slot.id,
                    answers: answers, ruleVersion: configuration.ruleVersion,
                    recommendedPracticeIDs: ["short-walk", "mindful-breathing"])
                data.checkIns.append(record)
                guard index == 0 || (index == 2 && offset % 3 == 0) else { continue }
                let seconds = Double(180 + (offset % 3) * 60)
                let end = completedAt.addingTimeInterval(seconds + 30)
                guard end < now else { continue }
                let completed = offset % 5 != 1
                let hasReflection = completed && offset % 3 == 0
                data.sessions.append(PracticeSession(id: UUID(), participantID: data.settings.participantID,
                    practiceID: offset % 2 == 0 ? "short-walk" : "mindful-breathing", checkInID: record.id,
                    startedAt: end.addingTimeInterval(-seconds), endedAt: end, durationSeconds: seconds,
                    completed: completed, helpfulness: hasReflection ? 4 : nil,
                    note: nil, completionSource: "self_report", entrySource: .recommendation,
                    feedbackUpdatedAt: hasReflection ? end.addingTimeInterval(20) : nil,
                    postPracticeDistress: hasReflection ? [2, 3, 4][(offset / 3) % 3] : nil,
                    postPracticeDistressRecordedAt: hasReflection ? end.addingTimeInterval(20) : nil))
            }
        }
        data.events = [StudyEvent(id: UUID(), timestamp: now, kind: "demo_fixture_loaded",
            referenceID: nil, details: ["source": "synthetic_demo_only", "purpose": "Illustrative app walkthrough"])]
        return data
    }
}
