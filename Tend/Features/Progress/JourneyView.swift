import SwiftUI

struct JourneyView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 32
    @State private var range = JourneyRange.week
    @State private var chart = JourneyChartKind.ratings
    private var analytics: JourneyAnalytics { JourneyAnalytics(data: store.data, configuration: store.configuration) }
    private var recentCheckIns: [CheckInRecord] { Array(store.data.checkIns.sorted { $0.completedAt > $1.completedAt }.prefix(3)) }
    private var recentSessions: [PracticeSession] { Array(store.data.sessions.sorted { $0.endedAt > $1.endedAt }.prefix(3)) }
    private var distressPairs: [PracticeDistressPair] { store.data.practiceDistressPairs }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.usesSampleHistory {
                        Label(store.isDemoMode ? "Illustrative demo data" : "Illustrative test data", systemImage: "testtube.2")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(TendTheme.terracotta)
                    }
                    weeklyProgress
                    VStack(spacing: 10) {
                        Picker("Time range", selection: $range) {
                            ForEach(JourneyRange.allCases) { item in
                                Text(item == .week ? "This week" : "28 days").tag(item)
                            }
                        }.pickerStyle(.segmented).accessibilityIdentifier("journey.range")
                        chartPicker
                        chartContent.id("\(range.rawValue)-\(chart.rawValue)")
                    }
                    if !distressPairs.isEmpty { pairedDistressSection }
                    recentCheckInSection
                    recentPracticeSection
                }.frame(maxWidth: 600).padding(24).frame(maxWidth: .infinity)
            }
            .tendScreen().navigationTitle("Journey").navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("journey.screen")
        }
    }

    @ViewBuilder private var chartPicker: some View {
        if typeSize.isAccessibilitySize {
            Picker("Chart", selection: $chart) { chartOptions }.pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("journey.chartKind")
        } else {
            Picker("Chart", selection: $chart) { chartOptions }.pickerStyle(.segmented)
                .accessibilityIdentifier("journey.chartKind")
        }
    }
    private var chartOptions: some View {
        ForEach(JourneyChartKind.allCases) { item in Text(item.rawValue).tag(item) }
    }
    @ViewBuilder private var chartContent: some View {
        let days = range == .week ? calendarWeek : analytics.days(in: .fourWeeks)
        switch chart {
        case .checkIns: CheckInWeekChart(days: days)
        case .practices: PracticeTimeChart(days: days)
        case .ratings:
            EMARatingsChart(records: store.data.checkIns.filter {
                $0.completedAt >= (days.first?.date ?? Date()) && $0.completedAt <= Date()
            }, days: days)
        }
    }

    private var weeklyProgress: some View {
        let days = currentWeekDays
        let studyDays = days.filter { $0.status == .active }
        let completed = studyDays.reduce(0) { $0 + $1.scheduledCount }
        let planned = studyDays.count * store.data.settings.reminders.count
        let practices = days.reduce(0) { $0 + $1.completedPracticeCount }
        let minutes = JourneyChartLayout.minutes(days.reduce(0) { $0 + $1.completedSeconds })
        let practiceLabel = "\(practices) \(practices == 1 ? "practice" : "practices")"
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Progress").font(.title3.weight(.semibold))
                Spacer()
                Text(weekDateLabel).font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(completed)/\(planned)")
                    .font(TendTheme.display(titleSize)).monospacedDigit()
                Text("scheduled check-ins")
                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
            if planned > 0 {
                ProgressView(value: Double(completed), total: Double(planned))
                    .tint(TendTheme.forest)
                    .accessibilityLabel("Scheduled check-ins this week")
                    .accessibilityValue("\(completed) of \(planned) planned through today")
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    Label(practiceLabel, systemImage: "checkmark.circle")
                    Spacer()
                    Text("\(minutes) min")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label(practiceLabel, systemImage: "checkmark.circle")
                    Text("\(minutes) min")
                }
            }
            .font(.subheadline).foregroundStyle(TendTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tendCard(TendTheme.sage.opacity(0.6))
        .accessibilityIdentifier("journey.weeklyProgress")
    }

    private var currentWeekDays: [JourneyDay] {
        calendarWeek.filter { $0.status != .future }
    }

    private var pairedDistressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent before and after · demo").font(.title3.weight(.semibold))
                Spacer()
                if distressPairs.count > 2 {
                    NavigationLink("See all") { PairedDistressHistoryView() }
                        .font(.subheadline)
                }
            }
            ForEach(distressPairs.prefix(2)) { pair in
                DistressPairRow(pair: pair, title: store.practice(id: pair.practiceID)?.title ?? pair.practiceID)
            }
            Text("Two self-reports, not a measure of effect.")
                .font(.subheadline).foregroundStyle(TendTheme.secondary)
        }
    }

    private var calendarWeek: [JourneyDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let daysSinceMonday = (calendar.component(.weekday, from: today) + 5) % 7
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - daysSinceMonday, to: today).map(analytics.day)
        }
    }

    private var weekDateLabel: String {
        guard let monday = calendarWeek.first?.date, let sunday = calendarWeek.last?.date else { return "" }
        return "\(monday.formatted(.dateTime.month(.abbreviated).day()))–\(sunday.formatted(.dateTime.month(.abbreviated).day()))"
    }
    private var recentCheckInSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent check-ins").font(.title3.weight(.semibold))
                Spacer()
                NavigationLink("See all") { CheckInHistoryView() }.font(.subheadline)
                    .accessibilityIdentifier("journey.allCheckIns")
            }.frame(minHeight: 44)
            if recentCheckIns.isEmpty {
                Text("No check-ins yet").font(.subheadline).foregroundStyle(TendTheme.secondary)
            } else {
                ForEach(recentCheckIns) { CheckInHistoryRow(record: $0) }
            }
        }
    }
    private var recentPracticeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent practices").font(.title3.weight(.semibold))
                Spacer()
                NavigationLink("See all") { PracticeHistoryView() }.font(.subheadline)
                    .accessibilityIdentifier("journey.allPractices")
            }.frame(minHeight: 44)
            if recentSessions.isEmpty {
                Text("No practices yet").font(.subheadline).foregroundStyle(TendTheme.secondary)
            } else {
                ForEach(recentSessions) { PracticeHistoryRow(session: $0) }
            }
        }
    }
}

private struct PairedDistressHistoryView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Before and after · demo")
                    .font(TendTheme.display(32))
                    .accessibilityAddTraits(.isHeader)
                Text("Two self-reports. A change does not show cause.")
                    .font(.body).foregroundStyle(TendTheme.secondary)
                    .padding(.bottom, 8)
                ForEach(store.data.practiceDistressPairs) { pair in
                    DistressPairRow(pair: pair, title: store.practice(id: pair.practiceID)?.title ?? pair.practiceID)
                }
            }
            .frame(maxWidth: 600).padding(24).frame(maxWidth: .infinity)
        }
        .tendScreen()
        .navigationTitle("Before and after")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DistressPairRow: View {
    @Environment(AppStore.self) private var store
    let pair: PracticeDistressPair
    let title: String

    var body: some View {
        Group {
            if let session = store.data.sessions.first(where: { $0.id == pair.sessionID }) {
                NavigationLink { PracticeSessionRecordView(session: session) } label: { content }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("journey.distressPair.\(pair.sessionID.uuidString)")
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer(minLength: 8)
                Text(pair.recordedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
            HStack(spacing: 10) {
                rating("At check-in", value: pair.before)
                Image(systemName: "arrow.right")
                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
                    .accessibilityHidden(true)
                rating("After practice", value: pair.after)
            }
            .accessibilityElement(children: .combine)
            Text("Check-in \(pair.checkInCompletedAt.formatted(date: .abbreviated, time: .shortened)) · After \(pair.recordedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(TendTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tendCard()
    }

    private func rating(_ label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline).foregroundStyle(TendTheme.secondary)
            Text("\(value) / 5").font(.title3.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum JourneyChartKind: String, CaseIterable, Identifiable {
    case ratings = "Ratings", checkIns = "Check-ins", practices = "Practices"
    var id: String { rawValue }
}
