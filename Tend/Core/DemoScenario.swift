import Foundation

/// Synthetic history relative to the preparation date. Today remains free for a walkthrough.
/// A fixed seed keeps the fixture reproducible without repeating a weekly pattern.
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
        var random = SampleRandom()
        // Uneven periods of higher/lower ratings, including a later increase.
        let dailyDistress = [3, 4, 3, 3, 2, 4, 3, 2, 2, 3, 4, 3, 2, 3,
                             2, 2, 3, 4, 3, 3, 2, 1, 2, 3, 4, 3, 3]
        let absentDays: Set<Int> = [3, 10, 18, 23]
        for offset in 0..<27 {
            guard !absentDays.contains(offset),
                  let day = calendar.date(byAdding: .day, value: offset, to: enrolled) else { continue }
            for (index, slot) in slots.enumerated() {
                let latestExample = offset == 26 && index == slots.count - 1
                // A mix of one, two, and three check-ins; some days have none.
                guard latestExample || index == 0 || random.number(0...99) >= 28,
                      let promptAt = calendar.date(bySettingHour: slot.hour, minute: slot.minute,
                                                   second: 0, of: day) else { continue }
                let completedAt = promptAt.addingTimeInterval(Double(random.number(2...42) * 60 + random.number(0...59)))
                guard completedAt < today else { continue }
                let distress = latestExample ? 3 : min(5, max(1, dailyDistress[offset] + random.number(-1...1)))
                let answers = EMAAnswers(distress: distress,
                    willingness: random.number(2...5), fatigue: random.number(1...4),
                    pain: random.number(1...3), physicalFunction: random.number(2...5),
                    availableTime: random.number(0...3) == 0 ? .under5 : .tenTo30)
                let suggested = (try? RuleEngine(configuration: configuration).recommend(for: answers)) ?? []
                let record = CheckInRecord(id: random.uuid(), participantID: data.settings.participantID,
                    startedAt: completedAt.addingTimeInterval(-Double(random.number(28...94))), completedAt: completedAt,
                    timezoneID: calendar.timeZone.identifier, origin: .scheduled, slotID: slot.id,
                    answers: answers, ruleVersion: configuration.ruleVersion,
                    recommendedPracticeIDs: suggested.map(\.id))
                data.checkIns.append(record)
                guard latestExample || random.number(0...99) < 43,
                      let practice = suggested.isEmpty ? nil : suggested[random.number(0...(suggested.count - 1))] else { continue }
                let completed = latestExample || random.number(0...99) >= 19
                let seconds = completed ? Double(practice.durationSeconds) : Double(random.number(15...max(16, practice.durationSeconds - 15)))
                let startedAt = completedAt.addingTimeInterval(Double(random.number(15...240)))
                let end = startedAt.addingTimeInterval(seconds + Double(random.number(0...45)))
                guard end < today else { continue }
                let hasReflection = completed && (latestExample || random.number(0...99) < 70)
                let after = latestExample ? 2 : min(5, max(1, distress + random.number(-2...1)))
                let reflectedAt = end.addingTimeInterval(Double(random.number(18...85)))
                data.sessions.append(PracticeSession(id: random.uuid(), participantID: data.settings.participantID,
                    practiceID: practice.id, checkInID: record.id, startedAt: startedAt, endedAt: end,
                    durationSeconds: seconds, completed: completed,
                    helpfulness: hasReflection ? random.number(2...5) : nil,
                    note: nil, completionSource: "self_report", entrySource: .recommendation,
                    feedbackUpdatedAt: hasReflection ? reflectedAt : nil,
                    postPracticeDistress: hasReflection ? after : nil,
                    postPracticeDistressRecordedAt: hasReflection ? reflectedAt : nil))
            }
        }
        data.events = [StudyEvent(id: random.uuid(), timestamp: now, kind: "demo_fixture_loaded",
            referenceID: nil, details: ["source": "synthetic_demo_only", "purpose": "Illustrative app walkthrough"])]
        return data
    }
}

private struct SampleRandom {
    private var state: UInt64 = 0x54454E445F3238

    mutating func number(_ range: ClosedRange<Int>) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return range.lowerBound + Int((state >> 32) % UInt64(range.upperBound - range.lowerBound + 1))
    }

    mutating func uuid() -> UUID {
        let bytes = (0..<16).map { _ in UInt8(number(0...255)) }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5],
                           (bytes[6] & 0x0f) | 0x40, bytes[7], (bytes[8] & 0x3f) | 0x80,
                           bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
