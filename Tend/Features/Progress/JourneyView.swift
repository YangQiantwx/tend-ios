import SwiftUI

struct JourneyView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 32
    @State private var range = JourneyRange.fourWeeks
    @State private var chart = JourneyChartKind.ratings
    private var analytics: JourneyAnalytics { JourneyAnalytics(data: store.data, configuration: store.configuration) }
    private var distressPairs: [PracticeDistressPair] { store.data.practiceDistressPairs }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.usesSampleHistory {
                        Label(store.isDemoMode ? "Sample history" : "Test history", systemImage: "testtube.2")
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
                    historySection
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
        let completed = studyDays.reduce(0) { $0 + $1.totalCheckIns }
        let practices = days.reduce(0) { $0 + $1.completedPracticeCount }
        let minutes = JourneyChartLayout.minutes(days.reduce(0) { $0 + $1.completedSeconds })
        let practiceLabel = "\(practices) \(practices == 1 ? "practice" : "practices")"
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(.title3.weight(.semibold))
                Spacer()
                Text(weekDateLabel).font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(completed)")
                    .font(TendTheme.display(titleSize)).monospacedDigit()
                Text(completed == 1 ? "check-in" : "check-ins")
                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    Label(practiceLabel, systemImage: "checkmark.circle")
                    Spacer()
                    Text("\(minutes) min total")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label(practiceLabel, systemImage: "checkmark.circle")
                    Text("\(minutes) min total")
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
                Text("Distress").font(.title3.weight(.semibold))
                Spacer()
                if distressPairs.count > 1 {
                    NavigationLink("See all") { PairedDistressHistoryView() }
                        .font(.subheadline)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("journey.allDistress")
                }
            }
            ForEach(distressPairs.prefix(1)) { pair in
                DistressPairRow(pair: pair, title: store.practice(id: pair.practiceID)?.title ?? pair.practiceID)
            }
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
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History").font(.title3.weight(.semibold))
            VStack(spacing: 0) {
                NavigationLink { CheckInHistoryView() } label: {
                    HistoryEntryLabel(title: "Check-in history", symbol: "calendar")
                }
                    .accessibilityIdentifier("journey.allCheckIns")
                Divider().overlay(TendTheme.line.opacity(0.4))
                    .padding(.leading, 52)
                NavigationLink { PracticeHistoryView() } label: {
                    HistoryEntryLabel(title: "Practice history", symbol: "leaf")
                }
                    .accessibilityIdentifier("journey.allPractices")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .background(TendTheme.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(TendTheme.line.opacity(0.45), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct HistoryEntryLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title3.weight(.medium))
                .foregroundStyle(TendTheme.forest)
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
            Text(title).font(.body.weight(.medium))
                .foregroundStyle(TendTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TendTheme.secondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct PairedDistressHistoryView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Distress over time")
                    .font(TendTheme.display(32))
                    .accessibilityAddTraits(.isHeader)
                Text("Your distress at check-in and after practice.")
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
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize = 32
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
        VStack(alignment: .leading, spacing: 24) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    practiceTitle
                    Spacer(minLength: 0)
                    recordedDate
                }
                VStack(alignment: .leading, spacing: 4) {
                    practiceTitle
                    recordedDate
                }
            }
            let meterLayout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 24))
            meterLayout {
                distressMeter("Before", context: "At check-in", score: pair.before, color: TendTheme.secondary)
                distressMeter("After", context: "After practice", score: pair.after, color: TendTheme.forest)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Distress at check-in \(pair.before) of 5, after practice \(pair.after) of 5. Lower means less distress.")
            Text("Lower scores mean less distress.")
                .font(.subheadline).foregroundStyle(TendTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("journey.distressScale")
        }
        .tendCard()
    }

    private var practiceTitle: some View {
        Text(title).font(.headline)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var recordedDate: some View {
        Text(pair.recordedAt.formatted(.dateTime.month(.abbreviated).day()))
            .font(.subheadline).foregroundStyle(TendTheme.secondary)
            .fixedSize()
    }

    private func distressMeter(_ label: String, context: String, score: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.weight(.medium))
                .foregroundStyle(TendTheme.secondary)
            Text(context).font(.caption).foregroundStyle(TendTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(score)").font(.system(size: scoreSize, weight: .semibold))
                    .foregroundStyle(TendTheme.ink)
                Text("/ 5").font(.body).foregroundStyle(TendTheme.secondary)
            }
            .monospacedDigit()
            HStack(spacing: 5) {
                ForEach(1...5, id: \.self) { level in
                    Capsule()
                        .fill(level <= score ? color : TendTheme.line.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .frame(height: 8)
                }
            }
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum JourneyChartKind: String, CaseIterable, Identifiable {
    case ratings = "Ratings", checkIns = "Check-ins", practices = "Practices"
    var id: String { rawValue }
}
