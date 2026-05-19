import SwiftUI

struct AuthLandingView: View {
    @State private var showRegister: Bool = false

    var body: some View {
        NavigationStack {
            LoginView()
                .navigationDestination(isPresented: $showRegister) {
                    RegisterView()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("auth.create_account") { showRegister = true }
                    }
                }
        }
    }
}
