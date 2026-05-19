import SwiftUI

struct RegisterView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var vm: AuthViewModel?

    var body: some View {
        Group {
            if let vm {
                form(vm: vm)
            } else {
                LoadingView()
            }
        }
        .onAppear {
            if vm == nil { vm = AuthViewModel(store: auth) }
        }
        .navigationTitle("auth.register.title")
    }

    @ViewBuilder
    private func form(vm: AuthViewModel) -> some View {
        @Bindable var vm = vm
        Form {
            Section("auth.section.required") {
                TextField("auth.username", text: $vm.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if let err = vm.usernameError { Text(err).foregroundStyle(.red).font(.caption) }

                SecureField("auth.password", text: $vm.password)
                    .textContentType(.newPassword)
                if let err = vm.passwordError { Text(err).foregroundStyle(.red).font(.caption) }
            }

            Section("auth.section.optional") {
                TextField("auth.full_name", text: $vm.fullName)
                TextField("auth.email", text: $vm.email)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                if let err = vm.emailError { Text(err).foregroundStyle(.red).font(.caption) }
            }

            if let err = auth.lastError {
                Section { Text(err).foregroundStyle(.red) }
            }

            Section {
                PrimaryButton(title: "auth.register.action", systemImage: "person.crop.circle.badge.plus", isWorking: vm.isWorking) {
                    Task {
                        if await vm.register() { dismiss() }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }
}
