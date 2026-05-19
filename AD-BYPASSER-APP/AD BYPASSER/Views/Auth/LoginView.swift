import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth
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
        .navigationTitle("auth.login.title")
    }

    @ViewBuilder
    private func form(vm: AuthViewModel) -> some View {
        @Bindable var vm = vm
        Form {
            Section {
                TextField("auth.username", text: $vm.username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if let err = vm.usernameError { Text(err).foregroundStyle(.red).font(.caption) }

                SecureField("auth.password", text: $vm.password)
                    .textContentType(.password)
                if let err = vm.passwordError { Text(err).foregroundStyle(.red).font(.caption) }
            }

            if let err = auth.lastError {
                Section { Text(err).foregroundStyle(.red) }
            }

            Section {
                PrimaryButton(title: "auth.login.action", systemImage: "arrow.right.circle.fill", isWorking: vm.isWorking) {
                    Task { await vm.login() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }
}
