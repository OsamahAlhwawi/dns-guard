import SwiftUI

struct UserDetailView: View {
    let user: User
    @Bindable var parentVM: AdminViewModel
    @State private var vm: AdminUserDetailViewModel
    @State private var limitText: String = ""
    @State private var showDeleteConfirm: Bool = false

    init(user: User, parentVM: AdminViewModel) {
        self.user = user
        self.parentVM = parentVM
        self._vm = State(initialValue: AdminUserDetailViewModel(user: user))
        self._limitText = State(initialValue: String(user.daily_limit))
    }

    var body: some View {
        List {
            Section("admin.user.identity") {
                LabeledContent("settings.username", value: user.username)
                LabeledContent("settings.role", value: user.role.rawValue)
                LabeledContent("admin.user.client_id", value: user.client_id)
                LabeledContent("admin.user.created", value: user.created_at)
                if let exp = user.expires_at { LabeledContent("admin.user.expires", value: exp) }
            }

            Section("admin.user.actions") {
                if !user.is_active {
                    Button("admin.activate") {
                        Task { await parentVM.activate(user) }
                    }
                    .tint(.green)
                }
                if user.is_suspended {
                    Button("admin.unsuspend") {
                        Task { await parentVM.unsuspend(user) }
                    }
                } else {
                    Button("admin.suspend") {
                        Task { await parentVM.suspend(user) }
                    }
                    .tint(.orange)
                }
                if user.role == .user {
                    Button("admin.promote") {
                        Task { await parentVM.setRole(user, role: .admin) }
                    }
                } else {
                    Button("admin.demote") {
                        Task { await parentVM.setRole(user, role: .user) }
                    }
                }

                HStack {
                    Text("admin.user.daily_limit")
                    Spacer()
                    TextField("", text: $limitText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                    Button("admin.apply") {
                        if let n = Int(limitText) {
                            Task { await parentVM.setDailyLimit(user, limit: n) }
                        }
                    }
                }

                Button("admin.delete", role: .destructive) { showDeleteConfirm = true }
            }

            if let s = vm.stats {
                Section("admin.user.stats") {
                    LabeledContent("admin.queries.today", value: s.today.queries.arabic)
                    LabeledContent("admin.blocked.today", value: s.today.blocked.arabic)
                }
            }

            Section("admin.user.recent_logs") {
                if vm.logEntries.isEmpty {
                    Text("admin.logs.empty").foregroundStyle(.secondary)
                } else {
                    ForEach(vm.logEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.question.name).font(.body.monospaced())
                                Spacer()
                                Image(systemName: entry.isBlocked ? "shield.lefthalf.filled" : "checkmark.circle")
                                    .foregroundStyle(entry.isBlocked ? .red : .green)
                            }
                            Text(entry.time).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let err = vm.lastError ?? parentVM.lastError {
                Section { Text(err).foregroundStyle(.red) }
            }
        }
        .navigationTitle(user.username)
        .refreshable { await vm.reload() }
        .task { await vm.reload() }
        .confirmationDialog("admin.delete_confirm", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("admin.delete", role: .destructive) {
                Task { await parentVM.delete(user) }
            }
            Button("common.cancel", role: .cancel) {}
        }
    }
}
