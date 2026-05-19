import SwiftUI

struct AppRoot: View {
    @Environment(AuthStore.self) private var auth
    @Binding var onboardingDone: Bool

    var body: some View {
        Group {
            if !onboardingDone {
                OnboardingView(onFinished: { onboardingDone = true })
            } else {
                switch auth.state {
                case .unauthenticated:
                    AuthLandingView()
                case .authenticating:
                    LoadingView()
                case .pendingActivation(let user):
                    PendingActivationView(user: user)
                case .authenticated(let user):
                    MainTabs(user: user)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stateID)
    }

    private var stateID: String {
        switch auth.state {
        case .unauthenticated: return "unauth"
        case .authenticating: return "loading"
        case .pendingActivation(let u): return "pending-\(u.id)"
        case .authenticated(let u): return "auth-\(u.id)"
        }
    }
}
