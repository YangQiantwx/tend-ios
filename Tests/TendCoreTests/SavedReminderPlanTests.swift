import Foundation
import Testing
@testable import TendCore

struct SavedReminderPlanTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func saved(after offset: TimeInterval = 0) -> SavedRecommendation {
        SavedRecommendation(id: UUID(), checkInID: UUID(), practiceIDs: ["walk", "breathe"],
                            savedAt: now.addingTimeInterval(offset),
                            expiresAt: now.addingTimeInterval(offset + 3600))
    }

    private func completed(_ practiceID: String, for item: SavedRecommendation) -> PracticeSession {
        PracticeSession(id: UUID(), participantID: "test", practiceID: practiceID,
                        checkInID: item.checkInID, startedAt: now, endedAt: now,
                        durationSeconds: 60, completed: true, helpfulness: nil,
                        note: nil, completionSource: "timer")
    }

    @Test func remindsBeforeExpiryAndKeepsPartlyCompletedOptions() {
        let item = saved()
        let plan = SavedReminderPlan.make(saved: [item], sessions: [completed("walk", for: item)],
                                         studyEndDate: now.addingTimeInterval(86400), now: now)
        #expect(plan.count == 1)
        #expect(plan.first?.date == now.addingTimeInterval(2700))
        #expect(plan.first?.checkInID == item.checkInID)
        #expect(SavedReminderPlan.make(saved: [item],
            sessions: item.practiceIDs.map { completed($0, for: item) },
            studyEndDate: now.addingTimeInterval(86400), now: now).isEmpty)
    }

    @Test func neverReplaysPastReminderOrSchedulesOutsideStudy() {
        let item = saved()
        #expect(SavedReminderPlan.make(saved: [item], sessions: [],
            studyEndDate: now.addingTimeInterval(86400), now: now.addingTimeInterval(2800)).isEmpty)
        #expect(SavedReminderPlan.make(saved: [item], sessions: [],
            studyEndDate: now.addingTimeInterval(2700), now: now).isEmpty)
        #expect(SavedReminderPlan.make(saved: [saved(after: 10)], sessions: [],
            studyEndDate: now.addingTimeInterval(86400), now: now).isEmpty)
    }

    @Test func reservesOnlyFourRequestsAndChoosesNearest() {
        let items = (0..<8).map { saved(after: Double(-$0 * 60)) }
        let plan = SavedReminderPlan.make(saved: items, sessions: [],
            studyEndDate: now.addingTimeInterval(86400), now: now)
        #expect(plan.count == 4)
        #expect(plan.map(\.savedID) == Array(items.reversed().prefix(4)).map(\.id))
    }

    @Test func lateSaveMustLeaveTimeForReminderBeforeExpiry() {
        var item = saved()
        item.expiresAt = now.addingTimeInterval(90)
        #expect(SavedReminderPlan.make(saved: [item], sessions: [],
            studyEndDate: now.addingTimeInterval(86400), now: now).first?.date == now.addingTimeInterval(60))
        item.expiresAt = now.addingTimeInterval(60)
        #expect(SavedReminderPlan.make(saved: [item], sessions: [],
            studyEndDate: now.addingTimeInterval(86400), now: now).isEmpty)
    }
}
