import SwiftUI

struct CheckInHistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var filter = CheckInHistoryFilter.all
    private var records: [CheckInRecord] {
        store.data.checkIns.filter { filter.origin == nil || $0.origin == filter.origin }
            .sorted { $0.completedAt > $1.completedAt }
    }
    private var dates: [Date] {
        Array(Set(records.map { Calendar.current.startOfDay(for: $0.completedAt) })).sorted(by: >)
    }
    var body: some View {
        List {
            Section {
                Picker("Check-in type", selection: $filter) {
                    ForEach(CheckInHistoryFilter.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu).accessibilityIdentifier("history.checkInFilter")
                Text("\(records.count) \(records.count == 1 ? "check-in" : "check-ins")").font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
            if records.isEmpty {
                EmptyMoment(symbol: "calendar", title: "No check-ins here yet", message: "Try another filter.")
            }
            ForEach(dates, id: \.self) { date in
                Section(date.formatted(date: .abbreviated, time: .omitted)) {
                    ForEach(records.filter { Calendar.current.isDate($0.completedAt, inSameDayAs: date) }) {
                        CheckInHistoryRow(record: $0, showsChevron: false)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).tendScreen().navigationTitle("All check-ins")
        .navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("history.checkIns")
    }
}

private enum CheckInHistoryFilter: String, CaseIterable, Identifiable {
    case all = "All", scheduled = "Scheduled", onDemand = "On demand"
    var id: String { rawValue }
    var origin: CheckInOrigin? {
        switch self {
        case .all: nil
        case .scheduled: .scheduled
        case .onDemand: .onDemand
        }
    }
}

struct PracticeHistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var filter = PracticeHistoryFilter.all
    @State private var search = ""
    private var sessions: [PracticeSession] {
        store.data.sessions.filter {
            (filter.matchedCompletion == nil || $0.completed == filter.matchedCompletion)
                && (search.isEmpty || (store.practice(id: $0.practiceID)?.title ?? "Practice").localizedCaseInsensitiveContains(search))
        }.sorted { $0.endedAt > $1.endedAt }
    }
    private var dates: [Date] {
        Array(Set(sessions.map { Calendar.current.startOfDay(for: $0.endedAt) })).sorted(by: >)
    }
    var body: some View {
        List {
            Section {
                Picker("Practice status", selection: $filter) {
                    ForEach(PracticeHistoryFilter.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu).accessibilityIdentifier("history.practiceFilter")
                Text("\(sessions.count) \(sessions.count == 1 ? "practice" : "practices")").font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
            if sessions.isEmpty {
                EmptyMoment(symbol: "leaf", title: "No practices here yet", message: "Try another search or change the status filter.")
            }
            ForEach(dates, id: \.self) { date in
                Section(date.formatted(date: .abbreviated, time: .omitted)) {
                    ForEach(sessions.filter { Calendar.current.isDate($0.endedAt, inSameDayAs: date) }) {
                        PracticeHistoryRow(session: $0, showsChevron: false)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Find a past practice")
        .scrollContentBackground(.hidden).tendScreen().navigationTitle("All practices")
        .navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("history.practices")
    }
}

private enum PracticeHistoryFilter: String, CaseIterable, Identifiable {
    case all = "All", completed = "Completed", endedEarly = "Ended early"
    var id: String { rawValue }
    var matchedCompletion: Bool? {
        switch self {
        case .all: nil
        case .completed: true
        case .endedEarly: false
        }
    }
}

struct JourneyDayDetailView: View {
    @Environment(AppStore.self) private var store
    let date: Date
    private var analytics: JourneyAnalytics { JourneyAnalytics(data: store.data, configuration: store.configuration) }
    var body: some View {
        let day = analytics.day(date)
        let checkIns = analytics.checkIns(on: date)
        let sessions = analytics.sessions(on: date)
        List {
            Section {
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.title2.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                LabeledContent("Scheduled check-ins", value: "\(day.scheduledCount)")
                LabeledContent("On-demand check-ins", value: "\(day.onDemandCount)")
                LabeledContent("Completed practices", value: "\(day.completedPracticeCount)")
                LabeledContent("Ended early", value: "\(day.endedEarlyCount)")
                if day.status != .active {
                    Text(day.status.label).font(.subheadline).foregroundStyle(TendTheme.secondary)
                } else if Calendar.current.isDateInToday(date) {
                    Text("Today so far").font(.subheadline).foregroundStyle(TendTheme.secondary)
                }
            }
            Section("Your check-ins") {
                if checkIns.isEmpty { Text("No check-ins recorded on this date.").foregroundStyle(TendTheme.secondary) }
                ForEach(checkIns) { CheckInHistoryRow(record: $0, showsChevron: false) }
            }
            Section("Your practices") {
                if sessions.isEmpty { Text("No practices recorded on this date.").foregroundStyle(TendTheme.secondary) }
                ForEach(sessions) { PracticeHistoryRow(session: $0, showsChevron: false) }
            }
        }
        .scrollContentBackground(.hidden).tendScreen().navigationTitle("A day in your journey")
        .navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("journey.dayDetail")
    }
}
