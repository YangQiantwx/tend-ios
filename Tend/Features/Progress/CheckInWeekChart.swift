import SwiftUI
import Charts

struct CheckInWeekChart: View {
    let days: [JourneyDay]
    @State private var selectedDate: Date?
    private var selected: JourneyDay? { JourneyChartLayout.selectedDay(selectedDate, from: days) }
    private var observedDays: [JourneyDay] { days.filter { $0.status != .future } }
    private var maximum: Int { max(3, observedDays.map(\.totalCheckIns).max() ?? 3) }
    private var count: Int { observedDays.reduce(0) { $0 + $1.totalCheckIns } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            JourneyChartHeading(title: "Recorded", value: "\(count)", unit: "check-ins")
            Chart {
                ForEach(observedDays) { day in
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Check-ins", day.scheduledCount), width: .ratio(0.58))
                        .foregroundStyle(by: .value("Type", "Scheduled"))
                        .accessibilityLabel(day.date.formatted(.dateTime.month().day()))
                        .accessibilityValue("\(day.scheduledCount) scheduled check-ins")
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Check-ins", day.onDemandCount), width: .ratio(0.58))
                        .foregroundStyle(by: .value("Type", "On demand"))
                        .accessibilityLabel(day.date.formatted(.dateTime.month().day()))
                        .accessibilityValue("\(day.onDemandCount) on-demand check-ins")
                }
                if let selected {
                    RuleMark(x: .value("Selected day", selected.date, unit: .day))
                        .foregroundStyle(TendTheme.secondary.opacity(0.35)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .accessibilityHidden(true)
                }
            }
            .chartForegroundStyleScale(["Scheduled": TendTheme.forest, "On demand": TendTheme.terracotta])
            .chartYScale(domain: 0...maximum)
            .chartXScale(domain: JourneyChartLayout.domain(for: days))
            .chartYAxis { AxisMarks(position: .leading, values: .stride(by: Double(max(1, Int(ceil(Double(maximum) / 4)))))) }
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
            .chartLegend(.hidden).tendDateSelection($selectedDate).frame(height: 172)
            .accessibilityLabel("Scheduled and on-demand check-ins by day")
            .accessibilityIdentifier("journey.checkInChart")
            HStack(spacing: 20) {
                ChartSeriesLabel(title: "Scheduled", color: TendTheme.forest, symbol: "sun.max")
                ChartSeriesLabel(title: "On demand", color: TendTheme.terracotta, symbol: "heart")
            }
            if count == 0 {
                Text("Your check-ins will appear here. An empty day is not a rating of how you feel.")
                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
            if let selected { JourneyChartDaySummary(day: selected, metric: .checkIns) }
            JourneyChartDataList(days: days, metric: .checkIns, selection: $selectedDate)
        }.tendCard()
    }
}
