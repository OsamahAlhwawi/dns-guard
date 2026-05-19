import SwiftUI

struct ProtectionToggleView: View {
    @Environment(AuthStore.self) private var auth
    let dns: DNSManager
    @State private var working: Bool = false
    @State private var lastError: String?

    private var protected: Bool { dns.isEnabled }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(lineWidth: 12)
                    .foregroundStyle(protected ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                Circle()
                    .trim(from: 0, to: protected ? 1 : 0.25)
                    .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .foregroundStyle(protected ? .green : .gray)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring, value: protected)

                VStack(spacing: 4) {
                    Image(systemName: protected ? "checkmark.shield.fill" : "shield.slash")
                        .font(.system(size: 44))
                        .foregroundStyle(protected ? .green : .gray)
                    Text(protected ? "dashboard.protected" : "dashboard.unprotected")
                        .font(.headline)
                }
            }
            .frame(width: 200, height: 200)

            HStack {
                StatusBadge(status: protected ? .active : .pending_activation)
                if let err = lastError {
                    Text(err).foregroundStyle(.red).font(.footnote)
                }
            }

            PrimaryButton(
                title: protected ? "dashboard.disable" : "dashboard.enable",
                systemImage: protected ? "pause.circle.fill" : "play.circle.fill",
                isWorking: working,
                isDestructive: protected
            ) {
                Task { await toggle() }
            }
        }
        .padding()
    }

    private func toggle() async {
        guard let user = auth.currentUser, let url = user.dohURL else { return }
        working = true
        defer { working = false }
        do {
            if protected {
                try await dns.disable()
            } else {
                try await dns.enable(dohURL: url)
            }
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
