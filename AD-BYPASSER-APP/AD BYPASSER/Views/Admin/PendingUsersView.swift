import SwiftUI

struct PendingUsersView: View {
    @Bindable var vm: AdminViewModel

    var body: some View {
        Group {
            if vm.pending.isEmpty {
                ContentUnavailableView("admin.pending.empty", systemImage: "checkmark.circle")
            } else {
                List {
                    ForEach(vm.pending) { user in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.username).font(.body.weight(.semibold))
                                Text(user.created_at).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("admin.activate") {
                                Task { await vm.activate(user) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .navigationTitle("admin.pending.list")
        .refreshable { await vm.reload() }
    }
}
