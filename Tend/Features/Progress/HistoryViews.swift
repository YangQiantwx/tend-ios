import SwiftUI

struct CheckInHistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var period = CheckInHistoryPeriod.all
    @State private var anchor: Date?
    private var referenceDate: Date { anchor ?? store.data.checkIns.map(\.completedAt).max() ?? Date() }
    private var records: [CheckInRecord] { period.records(store.data.checkIns, around: referenceDate) }
    private var dates: [Date] {
        Array(Set(records.map { Calendar.current.startOfDay(for: $0.completedAt) })).sorted(by: >)
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Picker("History period", selection: $period) {
                        ForEach(CheckInHistoryPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("history.period")
                    .onChange(of: period) { _, _ in anchor = nil }
                    if period != .all { periodNavigation }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            if records.isEmpty {
                ContentUnavailableView("No check-ins", systemImage: "calendar",
                    description: Text(period == .all ? "Your check-ins will appear here." : "Nothing recorded in this period."))
                    .listRowBackground(Color.clear)
            }
            ForEach(dates, id: \.self) { date in
                Section {
                    ForEach(records.filter { Calendar.current.isDate($0.completedAt, inSameDayAs: date) }) {
                        CheckInHistoryRow(record: $0, showsChevron: false, showsDate: false)
                    }
                } header: {
                    Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TendTheme.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden).tendScreen().navigationTitle("Check-ins")
        .navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("history.checkIns")
    }

    private var periodNavigation: some View {
        HStack(spacing: 8) {
            periodButton(offset: -1, symbol: "chevron.left", label: "Previous \(period.rawValue.lowercased())")
            Text(periodTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("history.periodTitle")
            periodButton(offset: 1, symbol: "chevron.right", label: "Next \(period.rawValue.lowercased())")
        }
    }

    private func periodButton(offset: Int, symbol: String, label: String) -> some View {
        Button { anchor = period.moving(offset, from: referenceDate) } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(TendTheme.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canMove(offset))
        .opacity(canMove(offset) ? 1 : 0.3)
        .accessibilityLabel(label)
        .accessibilityIdentifier(offset < 0 ? "history.previousPeriod" : "history.nextPeriod")
    }

    private func canMove(_ offset: Int) -> Bool {
        guard let first = store.data.checkIns.map(\.completedAt).min(),
              let last = store.data.checkIns.map(\.completedAt).max(),
              let interval = period.interval(containing: period.moving(offset, from: referenceDate)) else { return false }
        return interval.start <= last && interval.end > first
    }

    private var periodTitle: String {
        guard let interval = period.interval(containing: referenceDate) else { return "All check-ins" }
        if period == .month { return referenceDate.formatted(.dateTime.month(.wide).year()) }
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        let start = interval.start.formatted(.dateTime.month(.abbreviated).day())
        let end = lastDay.formatted(.dateTime.month(.abbreviated).day())
        let year = lastDay.formatted(.dateTime.year())
        return "\(start) – \(end), \(year)"
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
                ForEach(checkIns) { CheckInHistoryRow(record: $0, showsChevron: false, showsDate: false) }
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
