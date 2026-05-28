import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    private struct DayStat: Identifiable {
        let date: Date
        let focusMinutes: Double
        var id: Date { date }
    }

    private var weekData: [DayStat] {
        // Show the Sunday→Saturday week containing today, regardless of locale.
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let today = calendar.startOfDay(for: Date())
        let daysFromSunday = calendar.component(.weekday, from: today) - 1
        guard let sunday = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) else {
            return []
        }
        let days: [Date] = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: sunday)
        }

        return days.map { day in
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day)!
            let seconds = sessions
                .filter { $0.type == .focus && $0.startedAt >= day && $0.startedAt < dayEnd }
                .reduce(0.0) { $0 + $1.actualDuration }
            return DayStat(date: day, focusMinutes: seconds / 60)
        }
    }

    private var totalMinutesThisWeek: Int {
        Int(weekData.reduce(0) { $0 + $1.focusMinutes })
    }

    private var dailyAverageMinutes: Int {
        let nonZero = weekData.filter { $0.focusMinutes > 0 }.count
        guard nonZero > 0 else { return 0 }
        return totalMinutesThisWeek / max(1, nonZero)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 24) {
                metric(label: "This Week", value: totalMinutesThisWeek)
                metric(label: "Avg / Day", value: dailyAverageMinutes)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Chart(weekData) { stat in
                BarMark(
                    x: .value("Day", stat.date, unit: .day),
                    y: .value("Minutes", stat.focusMinutes)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                        .font(.system(size: 10))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let m = value.as(Double.self) {
                            Text("\(Int(m))m").font(.system(size: 10))
                        }
                    }
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                }
            }
            .frame(height: 220)
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    private func metric(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)")
                    .font(.system(size: 26, weight: .light, design: .rounded))
                    .monospacedDigit()
                Text("min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
