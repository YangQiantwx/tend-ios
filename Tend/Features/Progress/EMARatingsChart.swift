import SwiftUI
import Charts

struct EMARatingsChart: View {
    let records: [CheckInRecord]
    let days: [JourneyDay]
    @State private var rating = JourneyRating.distress
    @State private var selectedDate: Date?
    private var selected: JourneyDay? {
        if let selectedDate,
           let day = days.first(where: {
               $0.status != .future && Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
           }) {
            return day
        }
        return days.last(where: { $0.status != .future && $0.ratingCount > 0 })
            ?? days.last(where: { $0.status != .future })
    }
    private var selectedRating: DailyRating? {
        guard let selected else { return nil }
        return dailyRatings.first { Calendar.current.isDate($0.date, inSameDayAs: selected.date) }
    }

    /// One point per observed day. A new series starts after every day without a rating.
    private var dailyRatings: [DailyRating] {
        let calendar = Calendar.current
        let recordsByDay = Dictionary(grouping: records) { calendar.startOfDay(for: $0.completedAt) }
        var previousIndex: Int?
        var segment = 0
        return days.enumerated().compactMap { index, day in
            guard day.status != .future, let entries = recordsByDay[day.date], !entries.isEmpty else { return nil }
            if let previousIndex, index > previousIndex + 1 { segment += 1 }
            previousIndex = index
            let total = entries.reduce(0) { $0 + rating.value(in: $1.answers) }
            return DailyRating(date: day.date, average: Double(total) / Double(entries.count),
                               count: entries.count, segment: segment)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(rating.label) over time").font(.headline)
                Spacer(minLength: 8)
                Picker("Rating", selection: $rating) {
                    ForEach(JourneyRating.allCases) { item in Text(item.label).tag(item) }
                }.pickerStyle(.menu).tint(TendTheme.forest).accessibilityIdentifier("journey.ratingMetric")
            }
            Chart {
                ForEach(dailyRatings) { day in
                    LineMark(x: .value("Day", day.date, unit: .day),
                             y: .value("Daily average", day.average),
                             series: .value("Observed span", day.segment))
                        .foregroundStyle(TendTheme.forest)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    PointMark(x: .value("Day", day.date, unit: .day), y: .value("Daily average", day.average))
                        .foregroundStyle(TendTheme.forest)
                        .symbolSize(55)
                        .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("Average \(rating.label.lowercased()), \(day.averageLabel) of 5 from \(day.count) check-ins")
                }
                if let selected {
                    RuleMark(x: .value("Selected day", selected.date, unit: .day))
                        .foregroundStyle(TendTheme.secondary.opacity(0.35)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .accessibilityHidden(true)
                }
            }
            .chartYScale(domain: 0.5...5.5).chartXScale(domain: JourneyChartLayout.domain(for: days))
            .chartYAxis { AxisMarks(position: .leading, values: [1, 2, 3, 4, 5]) }
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
            .chartLegend(.hidden).tendDateSelection($selectedDate).frame(height: 200)
            .accessibilityLabel("Daily average \(rating.label.lowercased()) from recorded check-ins")
            .accessibilityIdentifier("journey.ratingsChart")
            Text(rating.anchors).font(.subheadline).foregroundStyle(TendTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if dailyRatings.isEmpty {
                Text("No ratings recorded in this period yet.")
                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
            }
            if let selected {
                NavigationLink { JourneyDayDetailView(date: selected.date) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(selected.date.formatted(.dateTime.month(.abbreviated).day())).font(.subheadline.weight(.semibold))
                            if let selectedRating {
                                Text("Average \(selectedRating.averageLabel) / 5 · \(selectedRating.count) \(selectedRating.count == 1 ? "check-in" : "check-ins")")
                                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
                            } else {
                                Text("No rating recorded · View this day")
                                    .font(.subheadline).foregroundStyle(TendTheme.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }.padding(14).frame(minHeight: 70)
                        .background(TendTheme.sage.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).accessibilityIdentifier("journey.selectedRatingDay")
            }
        }.tendCard()
    }
}

private struct DailyRating: Identifiable {
    let date: Date
    let average: Double
    let count: Int
    let segment: Int
    var id: Date { date }
    var averageLabel: String { average.formatted(.number.precision(.fractionLength(0...1))) }
}
