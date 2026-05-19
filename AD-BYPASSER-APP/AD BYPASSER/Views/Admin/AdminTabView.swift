import SwiftUI

struct AdminTabView: View {
    @State private var vm = AdminViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("admin.overview") {
                    if let o = vm.overview {
                        OverviewRow(labelKey: "admin.users.total", value: o.users.total.arabic)
                        OverviewRow(labelKey: "admin.users.active", value: o.users.active.arabic)
                        OverviewRow(labelKey: "admin.users.pending", value: o.users.pending.arabic)
                        OverviewRow(labelKey: "admin.users.suspended", value: o.users.suspended.arabic)
                        if let n = o.adguard?.num_dns_queries {
                            OverviewRow(labelKey: "admin.queries.total", value: n.arabic)
                        }
                        if let n = o.adguard?.num_blocked_filtering {
                            OverviewRow(labelKey: "admin.blocked.total", value: n.arabic)
                        }
                    } else {
                        Text("common.loading").foregroundStyle(.secondary)
                    }
                }

                Section {
                    NavigationLink(destination: PendingUsersView(vm: vm)) {
                        HStack {
                            Image(systemName: "hourglass")
                            Text("admin.pending.list")
                            Spacer()
                            Text(vm.pending.count.arabic).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink(destination: UsersListView(vm: vm)) {
                        HStack {
                            Image(systemName: "person.3")
                            Text("admin.users.list")
                            Spacer()
                            Text(vm.allUsers.count.arabic).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("tab.admin")
            .refreshable { await vm.reload() }
            .task { await vm.reload() }
        }
    }
}

private struct OverviewRow: View {
    let labelKey: LocalizedStringKey
    let value: String
    var body: some View {
        HStack {
            Text(labelKey).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit().fontWeight(.semibold)
        }
    }
}
