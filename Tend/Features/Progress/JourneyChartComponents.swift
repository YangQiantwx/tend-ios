import SwiftUI
import Charts

extension View {
    /// Tap a date without capturing the vertical drag used to scroll Journey.
    func tendDateSelection(_ selection: Binding<Date?>) -> some View {
        chartXSelection(value: selection)
            .chartGesture { proxy in
                SpatialTapGesture()
                    .onEnded { proxy.selectXValue(at: $0.location.x) }
            }
    }
}

enum JourneyChartLayout {
    static func selectedDay(_ selection: Date?, from days: [JourneyDay]) -> JourneyDay? {
        if let selection, let day = days.first(where: {
            $0.status != .future && Calendar.current.isDate($0.date, inSameDayAs: selection)
        }) {
            return day
        }
        return days.last(where: { $0.status != .future })
    }
    static func domain(for days: [JourneyDay]) -> ClosedRange<Date> {
        let start = days.first?.date ?? Calendar.current.startOfDay(for: Date())
        let last = days.last?.date ?? start
        let end = Calendar.current.date(byAdding: .day, value: 1, to: last) ?? last.addingTimeInterval(86_400)
        return start...end
    }
    static func minutes(_ seconds: Double) -> String {
        (seconds / 60).formatted(.number.precision(.fractionLength(0...1)))
    }
}

enum JourneyChartMetric {
    case checkIns, practiceTime
    func summary(_ day: JourneyDay) -> String {
        switch self {
        case .checkIns: "\(day.scheduledCount) scheduled · \(day.onDemandCount) on demand"
        case .practiceTime: "\(JourneyChartLayout.minutes(day.completedSeconds)) min · \(day.completedPracticeCount) completed"
        }
    }
}

struct JourneyChartHeading: View {
    let title: String
    let value: String
    let unit: String
    @ScaledMetric(relativeTo: .title) private var valueSize = 32
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value).font(TendTheme.display(valueSize)).monospacedDigit()
                Text(unit).font(.subheadline).foregroundStyle(TendTheme.secondary)
            }.accessibilityElement(children: .combine)
        }
    }
}

struct ChartSeriesLabel: View {
    let title: String
    let color: Color
    let symbol: String
    var body: some View {
        Label(title, systemImage: symbol).font(.caption.weight(.medium)).foregroundStyle(color)
    }
}

struct JourneyChartDaySummary: View {
    let day: JourneyDay
    let metric: JourneyChartMetric
    var body: some View {
        NavigationLink { JourneyDayDetailView(date: day.date) } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.subheadline.weight(.semibold))
                    Text(metric.summary(day)).font(.caption).foregroundStyle(TendTheme.secondary)
                    if day.status != .active {
                        Text(day.status.label).font(.caption).foregroundStyle(TendTheme.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.right").font(.subheadline)
            }
            .padding(14).frame(minHeight: 70)
            .background(TendTheme.sage.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this day's check-ins and practices")
        .accessibilityIdentifier(metric == .checkIns ? "journey.selectedCheckInDay" : "journey.selectedPracticeDay")
    }
}

struct JourneyChartDataList: View {
    let days: [JourneyDay]
    let metric: JourneyChartMetric
    @Binding var selection: Date?

    var body: some View {
        DisclosureGroup {
            VStack(spacing: 0) {
                ForEach(days.reversed().filter { $0.status != .future }) { day in
                    Button { selection = day.date } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(day.date.formatted(.dateTime.month(.abbreviated).day()))
                                Spacer()
                                if let selection, Calendar.current.isDate(day.date, inSameDayAs: selection) {
                                    Image(systemName: "checkmark").accessibilityHidden(true)
                                }
                            }.font(.subheadline.weight(.medium))
                            Text(metric.summary(day)).font(.caption).foregroundStyle(TendTheme.secondary)
                            if day.status != .active { Text(day.status.label).font(.caption).foregroundStyle(TendTheme.secondary) }
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain).accessibilityHint("Select this date in the chart")
                }
            }.padding(.top, 8)
        } label: {
            Label("View daily values", systemImage: "list.bullet").font(.subheadline).frame(minHeight: 44)
        }.tint(TendTheme.forest)
    }
}
