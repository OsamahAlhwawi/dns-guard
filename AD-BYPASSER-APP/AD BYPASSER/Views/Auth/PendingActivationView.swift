import SwiftUI

struct PendingActivationView: View {
    @Environment(AuthStore.self) private var auth
    let user: User
    @State private var checking: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hourglass.bottomhalf.filled")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("pending.title")
                .font(.title.bold())
            Text("pending.body")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 4) {
                Text("pending.username_label")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(user.username)
                    .font(.title3.monospaced())
            }

            Spacer()

            PrimaryButton(title: "pending.refresh", systemImage: "arrow.clockwise", isWorking: checking) {
                Task {
                    checking = true
                    await auth.refreshUser()
                    checking = false
                }
            }
            .padding(.horizontal, 24)

            Button("pending.logout", role: .destructive) {
                Task { await auth.logout() }
            }
            .padding(.bottom, 24)
        }
        .padding(.top, 48)
        .refreshable {
            await auth.refreshUser()
        }
    }
}
