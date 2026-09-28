import Foundation

/// A local walkthrough state. It never authorizes or connects to Fitbit.
struct FitbitDemoConnection: Codable, Sendable {
    var isConnected: Bool
    var connectedAt: Date
    var lastSyncedAt: Date?
    var source: String = "synthetic_demo"

    func validate() throws {
        guard source == "synthetic_demo", lastSyncedAt.map({ $0 >= connectedAt }) ?? true else {
            throw StudyValidationError.invalid("The Fitbit demo state is inconsistent.")
        }
    }

    static func sampleDays(at now: Date, calendar: Calendar = .current) -> [WearableDay] {
        let steps = [3820, 4200, 0, 3100, 4800, 2900, 3600]
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let missing = offset == 2
            return WearableDay(id: "fitbit-demo-day-\(offset)", date: day,
                steps: missing ? nil : steps[offset], activeMinutes: missing ? nil : 12 + offset,
                sleepHours: offset == 0 || missing ? nil : 6.5 + Double(offset % 3) * 0.4,
                restingHeartRate: missing ? nil : 64 + offset,
                syncedAt: missing ? nil : now, source: "synthetic_demo")
        }
    }
}
