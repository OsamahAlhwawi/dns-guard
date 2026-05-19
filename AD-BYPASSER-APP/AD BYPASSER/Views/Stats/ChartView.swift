import SwiftUI
import Charts

struct ChartView: View {
    let points: [HistoryPoint]

    var body: some View {
        if points.isEmpty {
            ContentUnavailableView("stats.empty", systemImage: "chart.bar.doc.horizontal")
        } else {
            Chart {
                ForEach(points) { p in
                    BarMark(
                        x: .value("date", p.date),
                        y: .value("queries", p.queries)
                    )
                    .foregroundStyle(.blue.opacity(0.5))

                    BarMark(
                        x: .value("date", p.date),
                        y: .value("blocked", p.blocked)
                    )
                    .foregroundStyle(.red)
                }
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) {
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
    }
}
