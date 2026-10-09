import Foundation
import Testing
@testable import TendCore

struct DemoScenarioTests {
    @Test func modesKeepDataPreferencesAndResetFlagsSeparate() {
        let root = URL(fileURLWithPath: "/tmp/Tend")
        #expect(AppDataMode.from(arguments: ["--demo"]) == .demo)
        #expect(AppDataMode.from(arguments: ["--demo", "--uitesting"]) == .uiTesting)
        #expect(AppDataMode.from(arguments: ["--reset-demo-data"]) == .standard)
        #expect(!AppDataMode.standard.shouldReset(arguments: ["--reset-demo-data", "--reset-test-data"]))
        #expect(!AppDataMode.demo.shouldReset(arguments: ["--reset-test-data"]))
        #expect(AppDataMode.demo.shouldReset(arguments: ["--reset-demo-data"]))
        #expect(Set([AppDataMode.standard, .demo, .uiTesting].map { $0.directory(in: root) }).count == 3)
        #expect(Set([AppDataMode.standard, .demo, .uiTesting].map { $0.preferenceKey("theme") }).count == 3)
        #expect(AppDataMode.standard.preferenceKey("theme") == "theme")
        #expect(!AppDataMode.demo.allowsSystemNotifications)
        #expect(!AppDataMode.uiTesting.allowsSystemNotifications)
    }

    @Test func mondayDemoHasRelativeHistoryMissingDaysAndNoCompletedTodaySlots() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 9))!
        #expect(calendar.component(.weekday, from: now) == 2)
        let configuration = try loadConfiguration()
        let data = DemoScenario.history(configuration: configuration, now: now, calendar: calendar)
        try data.validate()
        #expect(data.settings.audioEnabled)
        #expect(!data.settings.notificationsEnabled)
        #expect(data.checkIns.allSatisfy { $0.completedAt < calendar.startOfDay(for: now) })
        #expect(data.sessions.allSatisfy { $0.endedAt < now })
        #expect(data.events.first?.kind == "demo_fixture_loaded")
        let days = JourneyAnalytics(data: data, configuration: configuration, now: now, calendar: calendar).days(in: .fourWeeks)
        #expect(days.count == 28)
        #expect(days.filter { $0.ratingCount > 0 }.count > 15)
        #expect(days.contains { $0.status == .active && !$0.hasRecords })
        #expect(data.sessions.contains { !$0.completed })
        #expect(!data.practiceDistressPairs.isEmpty)
    }

    @Test func sampleHistoryIsReproducibleVariedAndLatestPairShowsLessDistress() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 9))!
        let configuration = try loadConfiguration()
        let first = DemoScenario.history(configuration: configuration, now: now, calendar: calendar)
        let second = DemoScenario.history(configuration: configuration, now: now, calendar: calendar)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(try encoder.encode(first) == encoder.encode(second))
        let latest = try #require(first.practiceDistressPairs.first)
        #expect(latest.before == 3)
        #expect(latest.after == 2)
        #expect(first.practiceDistressPairs.contains { $0.after > $0.before })
        #expect(first.practiceDistressPairs.contains { $0.after == $0.before })
        #expect(Set(first.sessions.map(\.practiceID)).count >= 4)
        #expect(Set(first.checkIns.map { calendar.component(.minute, from: $0.completedAt) }).count > 15)
        #expect(Set(first.checkIns.map { $0.answers.willingness }).count > 2)
        #expect(Set(first.checkIns.map { $0.answers.fatigue }).count > 2)
        for record in first.checkIns {
            let expected = try RuleEngine(configuration: configuration).recommend(for: record.answers).map(\.id)
            #expect(record.recommendedPracticeIDs == expected)
        }
        for session in first.sessions {
            #expect(session.endedAt.timeIntervalSince(session.startedAt) >= session.durationSeconds)
            if session.completed {
                #expect(session.durationSeconds == Double(configuration.practices.first { $0.id == session.practiceID }!.durationSeconds))
            }
        }
    }

    @Test func demoPreparationPreservesChangesOnSubsequentLaunches() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = try loadConfiguration()
        try DemoScenario.prepare(directory: directory, configuration: configuration)
        let repository = JSONStudyRepository(url: directory.appendingPathComponent("study-data.json"))
        var data = try #require(try repository.load())
        data.settings.displayName = "My saved demo name"
        try repository.save(data)
        let originalIDs = data.checkIns.map(\.id)
        try DemoScenario.prepare(directory: directory, configuration: configuration,
                                 now: Date().addingTimeInterval(86400))
        let restored = try #require(try repository.load())
        #expect(restored.settings.displayName == "My saved demo name")
        #expect(restored.checkIns.map(\.id) == originalIDs)
    }
}
