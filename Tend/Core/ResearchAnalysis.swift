import Foundation

enum ResearchPhase: String, Codable, Sendable {
    case notStarted, historyInitialization, development, heldOut, complete

    var title: String {
        switch self {
        case .notStarted: "Not started"
        case .historyInitialization: "Building a history"
        case .development: "Development period"
        case .heldOut: "Held-out period"
        case .complete: "Study complete"
        }
    }
}

enum ResearchLabelStatus: String, Codable, Sendable {
    case insufficientHistory, noHistorySamples, notElevated, elevated
}

struct ResearchDistressLabel: Codable, Identifiable, Sendable {
    var id: UUID { recordID }
    let recordID: UUID
    let completedAt: Date
    let slotID: String
    let phase: ResearchPhase
    let distress: Int
    let historyWindowStart: Date
    let historyRecordIDs: [UUID]
    let historySampleCount: Int
    let median: Double?
    let status: ResearchLabelStatus
}

enum ResearchTransitionStatus: String, Codable, Sendable {
    case pending, missingCurrent, missingNext, missingBoth, unknownLabel, nonChronological
    case currentAlreadyElevated, elevatedTransition, noElevation

    /// Only a known, non-elevated current state is eligible for this target.
    var transitionOccurred: Bool? {
        switch self {
        case .elevatedTransition: true
        case .noElevation: false
        default: nil
        }
    }
}

struct ResearchTransition: Codable, Identifiable, Sendable {
    let id: String
    let currentSlotID: String
    let nextSlotID: String
    let currentScheduledAt: Date
    let nextScheduledAt: Date
    let currentRecordID: UUID?
    let nextRecordID: UUID?
    let phase: ResearchPhase
    let observedIntervalSeconds: Double?
    /// Frozen before the current decision; the next EMA never changes this reference.
    /// Optional so snapshots exported by earlier versions remain decodable.
    var decisionReference: ResearchDecisionReference? = nil
    let status: ResearchTransitionStatus
}

struct ResearchDecisionReference: Codable, Sendable {
    let decisionAt: Date
    let historyWindowStart: Date
    let historyRecordIDs: [UUID]
    let median: Double?
}

struct ResearchExcludedRecord: Codable, Sendable {
    let recordID: UUID
    let reason: String
}

struct ResearchAnalysisCounts: Codable, Sendable {
    let includedScheduledCheckIns: Int
    let knownLabels: Int
    let elevatedLabels: Int
    let evaluableTransitions: Int
    let elevatedTransitions: Int
    let missingTransitions: Int
    let pendingTransitions: Int
}

/// Derived observations for research inspection/export. Never used by RuleEngine.
struct ResearchAnalysisSnapshot: Codable, Sendable {
    let sourceVersion: String
    let sourceParagraphs: [Int]
    let sourceConflict: String
    let limitations: [String]
    let generatedAt: Date
    let calendarIdentifier: String
    let timezoneID: String
    let orderedSlots: [ReminderSlot]
    let phase: ResearchPhase
    let studyDay: Int?
    let historyReadyAt: Date
    let analysisEndDate: Date
    let configuredStudyDurationDays: Int
    let includedRecordIDs: [UUID]
    let excludedRecords: [ResearchExcludedRecord]
    let labels: [ResearchDistressLabel]
    let transitions: [ResearchTransition]
    let counts: ResearchAnalysisCounts

    static func build(data: StudyData, configuration: StudyConfiguration,
                      now: Date = Date(), calendar: Calendar = .current) -> Self {
        ResearchAnalysisBuilder(data: data, configuration: configuration, now: now, calendar: calendar).build()
    }
}

private struct ResearchAnalysisBuilder {
    let data: StudyData
    let configuration: StudyConfiguration
    let now: Date
    let calendar: Calendar

    private var enrolledAt: Date { data.settings.enrolledAt }
    private var endDate: Date {
        adding(days: min(56, configuration.studyDurationDays), to: calendar.startOfDay(for: enrolledAt))
    }
    private var slots: [ReminderSlot] {
        data.settings.reminders.sorted {
            ($0.hour * 60 + $0.minute, $0.id) < ($1.hour * 60 + $1.minute, $1.id)
        }
    }

    func build() -> ResearchAnalysisSnapshot {
        let selection = selectRecords()
        let records = selection.records
        let labels = records.map { makeLabel(for: $0, records: records) }
        let transitions = makeTransitions(records: records, labels: labels)
        let counts = ResearchAnalysisCounts(
            includedScheduledCheckIns: records.count,
            knownLabels: labels.filter { [.notElevated, .elevated].contains($0.status) }.count,
            elevatedLabels: labels.filter { $0.status == .elevated }.count,
            evaluableTransitions: transitions.filter { $0.status.transitionOccurred != nil }.count,
            elevatedTransitions: transitions.filter { $0.status == .elevatedTransition }.count,
            missingTransitions: transitions.filter { [.missingCurrent, .missingNext, .missingBoth].contains($0.status) }.count,
            pendingTransitions: transitions.filter { $0.status == .pending }.count
        )
        return ResearchAnalysisSnapshot(
            sourceVersion: "demo-analysis-v1", sourceParagraphs: [],
            sourceConflict: "Demo schedule: week 1 builds history, weeks 2–6 are the development period, and weeks 7–8 are held out. These are demo analysis conventions, not model-validation results.",
            limitations: [
                "Observed labels only, not AI predictions, model evaluation, clinical assessment, or intervention rules.",
                "The historical window is [completion time minus 7 calendar days, completion time); current and future answers are excluded.",
                "A transition freezes the current decision's historical median for both endpoints. Later answers and samples expiring before the next EMA cannot change that target threshold. Each standalone EMA label describes its own preceding history.",
                "Labels remain unknown until 7 full calendar days after enrollment. No minimum observation count is invented; empty windows remain unknown and every sample count is reported.",
                "Only scheduled EMA for this participant is included. One record per local day and known slot is retained: earliest completion, then start time, then UUID.",
                "Day grouping and slot order use the supplied calendar/time zone and current reminder settings; historical schedule changes are not reconstructed.",
                "Only adjacent reminder slots within a day are paired. Missing slots, unknown labels, non-chronological responses, and an already-elevated current state are not negative outcomes.",
                "Actual observed intervals between decision points are exported without imposing an exclusion tolerance.",
                "Warm-up and phase boundaries use calendar-day anniversaries of actual enrollment. The administrative end matches the app schedule: the local start of the enrollment day plus 56 days or the configured duration, whichever is shorter.",
                "Prompt times represent planned opportunities, not verified notification delivery. Sensitivity definitions and AI training are not implemented."
            ],
            generatedAt: now, calendarIdentifier: String(describing: calendar.identifier),
            timezoneID: calendar.timeZone.identifier, orderedSlots: slots,
            phase: phase(at: now), studyDay: now >= enrolledAt && now < endDate ? elapsedDays(at: now) + 1 : nil,
            historyReadyAt: adding(days: 7, to: enrolledAt), analysisEndDate: endDate,
            configuredStudyDurationDays: configuration.studyDurationDays,
            includedRecordIDs: records.map(\.id), excludedRecords: selection.excluded,
            labels: labels, transitions: transitions, counts: counts
        )
    }

    private func selectRecords() -> (records: [CheckInRecord], excluded: [ResearchExcludedRecord]) {
        let slotIDs = Set(slots.map(\.id))
        var seen: Set<SlotDay> = []
        var records: [CheckInRecord] = []
        var excluded: [ResearchExcludedRecord] = []
        let ordered = data.checkIns.sorted {
            if $0.completedAt != $1.completedAt { return $0.completedAt < $1.completedAt }
            if $0.startedAt != $1.startedAt { return $0.startedAt < $1.startedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        for record in ordered {
            let reason: String?
            if record.participantID != data.settings.participantID { reason = "differentParticipant" }
            else if record.origin != .scheduled { reason = "onDemand" }
            else if record.completedAt > now { reason = "futureObservation" }
            else if record.completedAt < enrolledAt || record.completedAt >= endDate { reason = "outsideStudy" }
            else if !slotIDs.contains(record.slotID ?? "") { reason = "unknownReminderSlot" }
            else if !seen.insert(key(record)).inserted { reason = "duplicateDayAndSlot" }
            else { reason = nil }
            if let reason { excluded.append(ResearchExcludedRecord(recordID: record.id, reason: reason)) }
            else { records.append(record) }
        }
        return (records, excluded)
    }

    private func makeLabel(for record: CheckInRecord, records: [CheckInRecord]) -> ResearchDistressLabel {
        let start = adding(days: -7, to: record.completedAt)
        let history = records.filter { $0.completedAt >= start && $0.completedAt < record.completedAt }
        let scores = history.map { Double($0.answers.distress) }.sorted()
        let median: Double?
        let status: ResearchLabelStatus
        if start < enrolledAt {
            median = nil
            status = .insufficientHistory
        } else if scores.isEmpty {
            median = nil
            status = .noHistorySamples
        } else {
            let middle = scores.count / 2
            let threshold = scores.count.isMultiple(of: 2) ? (scores[middle - 1] + scores[middle]) / 2 : scores[middle]
            median = threshold
            status = Double(record.answers.distress) > threshold ? .elevated : .notElevated
        }
        return ResearchDistressLabel(recordID: record.id, completedAt: record.completedAt,
            slotID: record.slotID ?? "", phase: phase(at: record.completedAt), distress: record.answers.distress,
            historyWindowStart: start, historyRecordIDs: history.map(\.id), historySampleCount: history.count,
            median: median, status: status)
    }

    private func makeTransitions(records: [CheckInRecord], labels: [ResearchDistressLabel]) -> [ResearchTransition] {
        guard now >= enrolledAt, slots.count >= 2 else { return [] }
        let bySlot = Dictionary(uniqueKeysWithValues: records.map { (key($0), $0) })
        let byID = Dictionary(uniqueKeysWithValues: labels.map { ($0.recordID, $0) })
        var result: [ResearchTransition] = []
        var day = calendar.startOfDay(for: enrolledAt)
        while day <= now && day < endDate {
            for (currentSlot, nextSlot) in zip(slots, slots.dropFirst()) {
                guard let currentDate = scheduledDate(slot: currentSlot, day: day),
                      let nextDate = scheduledDate(slot: nextSlot, day: day),
                      currentDate >= enrolledAt, nextDate < endDate else { continue }
                let current = bySlot[SlotDay(day: day, slotID: currentSlot.id)]
                let next = bySlot[SlotDay(day: day, slotID: nextSlot.id)]
                let reference = current.flatMap { byID[$0.id] }.map {
                    ResearchDecisionReference(decisionAt: $0.completedAt,
                                              historyWindowStart: $0.historyWindowStart,
                                              historyRecordIDs: $0.historyRecordIDs, median: $0.median)
                }
                let status = transitionStatus(current: current, next: next, currentDate: currentDate,
                                              nextDate: nextDate, labels: byID)
                result.append(ResearchTransition(
                    id: "\(Int(day.timeIntervalSince1970)).\(currentSlot.id).\(nextSlot.id)",
                    currentSlotID: currentSlot.id, nextSlotID: nextSlot.id,
                    currentScheduledAt: currentDate, nextScheduledAt: nextDate,
                    currentRecordID: current?.id, nextRecordID: next?.id, phase: phase(at: nextDate),
                    observedIntervalSeconds: current.flatMap { first in next.map { $0.completedAt.timeIntervalSince(first.completedAt) } },
                    decisionReference: reference,
                    status: status
                ))
            }
            let following = adding(days: 1, to: day)
            guard following > day else { break }
            day = following
        }
        return result
    }

    private func transitionStatus(current: CheckInRecord?, next: CheckInRecord?, currentDate: Date,
                                  nextDate: Date, labels: [UUID: ResearchDistressLabel]) -> ResearchTransitionStatus {
        if (current == nil && currentDate > now) || (next == nil && nextDate > now) { return .pending }
        guard let current else { return next == nil ? .missingBoth : .missingCurrent }
        guard let next else { return .missingNext }
        guard next.completedAt > current.completedAt else { return .nonChronological }
        guard let first = labels[current.id], let threshold = first.median,
              [.notElevated, .elevated].contains(first.status) else { return .unknownLabel }
        guard first.status == .notElevated else { return .currentAlreadyElevated }
        return Double(next.answers.distress) > threshold ? .elevatedTransition : .noElevation
    }

    private func phase(at date: Date) -> ResearchPhase {
        if date < enrolledAt { return .notStarted }
        if date >= endDate { return .complete }
        switch elapsedDays(at: date) {
        case ..<7: return .historyInitialization
        case 7..<42: return .development
        default: return .heldOut
        }
    }

    private func elapsedDays(at date: Date) -> Int {
        calendar.dateComponents([.day], from: enrolledAt, to: date).day ?? 0
    }

    private func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    private func scheduledDate(slot: ReminderSlot, day: Date) -> Date? {
        guard let date = calendar.nextDate(after: day.addingTimeInterval(-1),
            matching: DateComponents(hour: slot.hour, minute: slot.minute, second: 0),
            matchingPolicy: .nextTime, repeatedTimePolicy: .first),
            calendar.isDate(date, inSameDayAs: day) else { return nil }
        return date
    }

    private func key(_ record: CheckInRecord) -> SlotDay {
        SlotDay(day: calendar.startOfDay(for: record.completedAt), slotID: record.slotID ?? "")
    }

    private struct SlotDay: Hashable {
        let day: Date
        let slotID: String
    }
}
