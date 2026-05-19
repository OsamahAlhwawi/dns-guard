import SwiftUI

struct UsersListView: View {
    @Bindable var vm: AdminViewModel
    @State private var query: String = ""

    var filtered: [User] {
        guard !query.isEmpty else { return vm.allUsers }
        return vm.allUsers.filter { $0.username.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            ForEach(filtered) { user in
                NavigationLink(destination: UserDetailView(user: user, parentVM: vm)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.username).font(.body.weight(.semibold))
                            HStack(spacing: 6) {
                                if user.isAdmin {
                                    Text("admin.badge")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.purple)
                                }
                                statusBadge(for: user)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .searchable(text: $query, prompt: Text("admin.search"))
        .navigationTitle("admin.users.list")
        .refreshable { await vm.reload() }
    }

    @ViewBuilder
    private func statusBadge(for user: User) -> some View {
        if user.is_suspended {
            StatusBadge(status: .suspended)
        } else if !user.is_active {
            StatusBadge(status: .pending_activation)
        } else {
            StatusBadge(status: .active)
        }
    }
}
