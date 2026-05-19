import SwiftUI
import Charts

struct StatsView: View {
    @State private var vm = StatsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("stats.period", selection: $vm.period) {
                        ForEach(StatsViewModel.Period.allCases) { p in
                            Text(String(localized: p.titleKey)).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if let t = vm.today {
                        HStack(spacing: 12) {
                            StatCard(title: "stats.today.queries", value: t.queries.arabic, systemImage: "magnifyingglass")
                            StatCard(title: "stats.today.blocked", value: t.blocked.arabic, systemImage: "shield.lefthalf.filled", tint: .red)
                        }
                        .padding(.horizontal)
                    }

                    ChartView(points: vm.points)
                        .frame(height: 220)
                        .padding(.horizontal)

                    if let err = vm.lastError {
                        Text(err).foregroundStyle(.red).font(.footnote)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("tab.stats")
            .refreshable { await vm.reload() }
            .task { await vm.reload() }
        }
    }
}
