import SwiftUI
import Charts

struct PracticeTimeChart: View {
    let days: [JourneyDay]
    @State private var selectedDate: Date?
    private var selected: JourneyDay? { JourneyChartLayout.selectedDay(selectedDate, from: days) }
    private var observedDays: [JourneyDay] { days.filter { $0.status != .future } }
    private var seconds: Double { observedDays.reduce(0) { $0 + $1.completedSeconds } }
    private var maximum: Double { max(1, ceil((observedDays.map(\.completedSeconds).max() ?? 0) / 60)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            JourneyChartHeading(title: "Time for yourself", value: JourneyChartLayout.minutes(seconds), unit: "minutes in completed practices")
            Chart {
                ForEach(observedDays) { day in
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Minutes", day.movementSeconds / 60), width: .ratio(0.58))
                        .foregroundStyle(by: .value("Practice", "Movement"))
                        .accessibilityLabel(day.date.formatted(.dateTime.month().day()))
                        .accessibilityValue("\(JourneyChartLayout.minutes(day.movementSeconds)) movement minutes")
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Minutes", day.mindfulnessSeconds / 60), width: .ratio(0.58))
                        .foregroundStyle(by: .value("Practice", "Mindfulness"))
                        .accessibilityLabel(day.date.formatted(.dateTime.month().day()))
                        .accessibilityValue("\(JourneyChartLayout.minutes(day.mindfulnessSeconds)) mindfulness minutes")
                    if day.unclassifiedSeconds > 0 {
                        BarMark(x: .value("Day", day.date, unit: .day), y: .value("Minutes", day.unclassifiedSeconds / 60), width: .ratio(0.58))
                            .foregroundStyle(by: .value("Practice", "Past library content"))
                            .accessibilityLabel(day.date.formatted(.dateTime.month().day()))
                            .accessibilityValue("\(JourneyChartLayout.minutes(day.unclassifiedSeconds)) minutes in past library content")
                    }
                }
                if let selected {
                    RuleMark(x: .value("Selected day", selected.date, unit: .day))
                        .foregroundStyle(TendTheme.secondary.opacity(0.35)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .accessibilityHidden(true)
                }
            }
            .chartForegroundStyleScale(["Movement": TendTheme.forest, "Mindfulness": TendTheme.terracotta, "Past library content": TendTheme.secondary])
            .chartYScale(domain: 0...maximum).chartXScale(domain: JourneyChartLayout.domain(for: days))
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
            .chartXAxis {
                if days.count > 7 {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                } else {
                    AxisMarks(values: days.map(\.date)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
            }
            .chartLegend(.hidden).tendDateSelection($selectedDate).frame(height: 150)
            .accessibilityLabel("Active minutes in completed practices by day").accessibilityIdentifier("journey.practiceChart")
            HStack(spacing: 20) {
                ChartSeriesLabel(title: "Movement", color: TendTheme.forest, symbol: "figure.walk")
                ChartSeriesLabel(title: "Mindfulness", color: TendTheme.terracotta, symbol: "leaf")
            }
            if observedDays.contains(where: { $0.unclassifiedSeconds > 0 }) {
                ChartSeriesLabel(title: "Past library content", color: TendTheme.secondary, symbol: "archivebox")
            }
            if seconds == 0 {
                Text("A little time is enough. Your first completed practice will appear here.")
                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
            if let selected { JourneyChartDaySummary(day: selected, metric: .practiceTime) }
            JourneyChartDataList(days: days, metric: .practiceTime, selection: $selectedDate)
        }.tendCard()
    }
}
