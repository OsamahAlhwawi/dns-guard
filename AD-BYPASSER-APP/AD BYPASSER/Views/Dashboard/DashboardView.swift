import SwiftUI

struct DashboardView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @State private var vm = DashboardViewModel()
    private let dns = DNSManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ProtectionToggleView(dns: dns)
                        .padding(.top, 16)

                    quickStats

                    if let err = vm.lastError {
                        Text(err).foregroundStyle(.red).font(.footnote)
                    }
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("tab.dashboard")
            .refreshable { await vm.refresh() }
            .task {
                await dns.refresh()
                vm.startPolling()
            }
            .onDisappear { vm.stopPolling() }
            .onChange(of: scenePhase) { _, new in
                if new == .active {
                    Task { await dns.refresh(); await vm.refresh() }
                }
            }
        }
    }

    private var dailyLimitLabel: String {
        let n = vm.todayStats?.daily_limit ?? 0
        return n <= 0 ? String(localized: "dashboard.unlimited") : n.arabic
    }

    private var quickStats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "dashboard.queries_today",
                value: (vm.todayStats?.queries ?? 0).arabic,
                systemImage: "magnifyingglass"
            )
            StatCard(
                title: "dashboard.blocked_today",
                value: (vm.todayStats?.blocked ?? 0).arabic,
                systemImage: "shield.lefthalf.filled",
                tint: .red
            )
            StatCard(
                title: "dashboard.block_ratio",
                value: (vm.todayStats?.block_ratio ?? 0).arabicPercent,
                systemImage: "percent",
                tint: .orange
            )
            StatCard(
                title: "dashboard.daily_limit",
                value: dailyLimitLabel,
                systemImage: "gauge.with.dots.needle.50percent",
                tint: .blue
            )
        }
    }
}
