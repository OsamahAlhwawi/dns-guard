import SwiftUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @State private var vm: SettingsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    form(vm: vm)
                } else {
                    LoadingView()
                }
            }
            .navigationTitle("tab.settings")
            .onAppear {
                if vm == nil { vm = SettingsViewModel(store: auth) }
            }
        }
    }

    @ViewBuilder
    private func form(vm: SettingsViewModel) -> some View {
        @Bindable var vm = vm
        Form {
            if let user = auth.currentUser {
                Section("settings.account") {
                    LabeledContent("settings.username", value: user.username)
                    LabeledContent("settings.role", value: user.role.rawValue)
                    LabeledContent("settings.plan", value: user.plan)
                }
            }

            Section("settings.profile") {
                TextField("auth.full_name", text: $vm.fullName)
                TextField("auth.email", text: $vm.email)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                Button("settings.save") { Task { await vm.saveProfile() } }
            }

            Section("settings.security") {
                SecureField("settings.current_password", text: $vm.currentPassword)
                SecureField("settings.new_password", text: $vm.newPassword)
                if let err = vm.newPasswordError { Text(err).foregroundStyle(.red).font(.caption) }
                Button("settings.change_password") { Task { _ = await vm.changePassword() } }
            }

            if let msg = vm.lastMessage {
                Section { Text(msg).foregroundStyle(.green) }
            }

            if auth.currentUser?.isAdmin == true {
                Section("settings.advanced") {
                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        Label("settings.diagnostics", systemImage: "stethoscope")
                    }
                }
            }

            Section {
                Button("settings.sign_out", role: .destructive) {
                    Task { await vm.logout() }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
