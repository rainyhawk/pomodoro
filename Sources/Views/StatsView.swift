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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days: [Date] = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: -(6 - $0), to: today)
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
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week")
                        .font(.headline)
                    Text("\(totalMinutesThisWeek) min total · \(dailyAverageMinutes) min/day avg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Chart(weekData) { stat in
                BarMark(
                    x: .value("Day", stat.date, unit: .day),
                    y: .value("Minutes", stat.focusMinutes)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let m = value.as(Double.self) {
                            Text("\(Int(m))m")
                        }
                    }
                    AxisGridLine()
                }
            }
            .frame(height: 220)
            .padding(.horizontal)

            Spacer()
        }
    }
}
