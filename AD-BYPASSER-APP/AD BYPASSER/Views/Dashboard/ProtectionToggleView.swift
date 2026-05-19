import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ProtectionToggleView: View {
    @Environment(AuthStore.self) private var auth
    let dns: DNSManager
    @State private var working: Bool = false
    @State private var lastError: String?

    private var protected: Bool { dns.isEnabled }
    /// Profile saved but not the active DNS — user must select it in Settings.
    private var needsSelection: Bool { dns.isInstalled && !dns.isEnabled }

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

            StatusBadge(status: protected ? .active : .pending_activation)

            if needsSelection {
                instructionsCard
            }

            if let err = lastError {
                Text(err).foregroundStyle(.red).font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            PrimaryButton(
                title: protected
                    ? "dashboard.disable"
                    : needsSelection ? "dashboard.open_settings" : "dashboard.enable",
                systemImage: protected
                    ? "pause.circle.fill"
                    : needsSelection ? "arrow.up.right.square" : "play.circle.fill",
                isWorking: working,
                isDestructive: protected
            ) {
                Task { await primaryAction() }
            }
        }
        .padding()
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("dashboard.profile.installed", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
            Text("dashboard.profile.next_step")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func primaryAction() async {
        guard let user = auth.currentUser, let url = user.dohURL else { return }

        if protected {
            await runWork { try await dns.disable() }
            return
        }

        if needsSelection {
            openIOSSettings()
            return
        }

        await runWork {
            if dns.isInstalled {
                try await dns.reinstall(dohURL: url)
            } else {
                try await dns.enable(dohURL: url)
            }
            // After install, refresh; if iOS auto-selected the profile, the UI
            // will flip to "protected" on its own. Otherwise the user sees the
            // instructions card + "Open Settings" button on the next press.
            await dns.refresh()
        }
    }

    private func runWork(_ block: () async throws -> Void) async {
        working = true
        defer { working = false }
        do {
            try await block()
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func openIOSSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
