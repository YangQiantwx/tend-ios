import Foundation

enum JourneyRange: Int, CaseIterable, Identifiable, Sendable {
    case week = 7
    case fourWeeks = 28
    var id: Int { rawValue }
    var label: String { "\(rawValue) days" }
}

enum JourneyDayStatus: String, Sendable {
    case beforeEnrollment, active, afterStudy, future

    var label: String {
        switch self {
        case .beforeEnrollment: "Before enrollment"
        case .active: "Study day"
        case .afterStudy: "After the study"
        case .future: "Not yet reached"
        }
    }
}

struct JourneyDay: Identifiable, Sendable {
    let date: Date
    let status: JourneyDayStatus
    let scheduledCount: Int
    let onDemandCount: Int
    let completedPracticeCount: Int
    let endedEarlyCount: Int
    let movementSeconds: Double
    let mindfulnessSeconds: Double
    let unclassifiedSeconds: Double
    let endedEarlySeconds: Double
    let ratingCount: Int
    var id: Date { date }
    var totalCheckIns: Int { scheduledCount + onDemandCount }
    var completedSeconds: Double { movementSeconds + mindfulnessSeconds + unclassifiedSeconds }
    var hasRecords: Bool { totalCheckIns > 0 || completedPracticeCount + endedEarlyCount > 0 }
}

enum JourneyRating: String, CaseIterable, Identifiable, Sendable {
    case distress, willingness, fatigue, pain, physicalFunction
    var id: String { rawValue }
    var label: String {
        switch self {
        case .distress: "Distress"
        case .willingness: "Willingness"
        case .fatigue: "Fatigue"
        case .pain: "Pain"
        case .physicalFunction: "Physical ability"
        }
    }
    var anchors: String {
        switch self {
        case .distress, .fatigue: "1 · Not at all     5 · Extremely"
        case .willingness: "1 · Not at all willing     5 · Extremely willing"
        case .pain: "1 · None     5 · Severe"
        case .physicalFunction: "1 · Not at all able     5 · Extremely able"
        }
    }
    func value(in answers: EMAAnswers) -> Int {
        switch self {
        case .distress: answers.distress
        case .willingness: answers.willingness
        case .fatigue: answers.fatigue
        case .pain: answers.pain
        case .physicalFunction: answers.physicalFunction
        }
    }
}

/// One shared, Foundation-only projection for charts, summaries and day detail.
/// Completed minutes are measured active time in self-reported completed sessions.
/// Missing questionnaire observations are never manufactured or interpolated.
struct JourneyAnalytics: Sendable {
    let data: StudyData
    let configuration: StudyConfiguration
    let now: Date
    let calendar: Calendar

    init(data: StudyData, configuration: StudyConfiguration, now: Date = Date(), calendar: Calendar = .current) {
        self.data = data
        self.configuration = configuration
        self.now = now
        self.calendar = calendar
    }

    func days(in range: JourneyRange, endingOn end: Date? = nil) -> [JourneyDay] {
        let finalDay = calendar.startOfDay(for: end ?? now)
        return (0..<range.rawValue).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: finalDay).map(day)
        }
    }

    func day(_ date: Date) -> JourneyDay {
        let start = calendar.startOfDay(for: date)
        let checkIns = checkIns(on: start)
        let sessions = sessions(on: start)
        let completed = sessions.filter(\.completed)
        let practiceCategories = Dictionary(uniqueKeysWithValues: configuration.practices.map { ($0.id, $0.category) })
        func seconds(_ category: PracticeCategory) -> Double {
            completed.filter { practiceCategories[$0.practiceID] == category }
                .reduce(0) { $0 + max(0, $1.durationSeconds) }
        }
        return JourneyDay(date: start, status: status(on: start),
            scheduledCount: Set(checkIns.filter { $0.origin == .scheduled }.compactMap(\.slotID)).count,
            onDemandCount: checkIns.filter { $0.origin == .onDemand }.count,
            completedPracticeCount: completed.count,
            endedEarlyCount: sessions.filter { !$0.completed }.count,
            movementSeconds: seconds(.movement), mindfulnessSeconds: seconds(.mindfulness),
            unclassifiedSeconds: completed.filter { practiceCategories[$0.practiceID] == nil }.reduce(0) { $0 + max(0, $1.durationSeconds) },
            endedEarlySeconds: sessions.filter { !$0.completed }.reduce(0) { $0 + max(0, $1.durationSeconds) },
            ratingCount: checkIns.count)
    }

    func checkIns(on date: Date) -> [CheckInRecord] {
        data.checkIns.filter { $0.completedAt <= now && calendar.isDate($0.completedAt, inSameDayAs: date) }
            .sorted { $0.completedAt > $1.completedAt }
    }

    func sessions(on date: Date) -> [PracticeSession] {
        data.sessions.filter { $0.endedAt <= now && calendar.isDate($0.endedAt, inSameDayAs: date) }
            .sorted { $0.endedAt > $1.endedAt }
    }

    func status(on date: Date) -> JourneyDayStatus {
        let start = calendar.startOfDay(for: date)
        let enrollment = calendar.startOfDay(for: data.settings.enrolledAt)
        let studyEnd = calendar.date(byAdding: .day, value: configuration.studyDurationDays, to: enrollment) ?? enrollment
        if start > calendar.startOfDay(for: now) { return .future }
        if start < enrollment { return .beforeEnrollment }
        if start >= studyEnd { return .afterStudy }
        return .active
    }
}
