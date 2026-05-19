import SwiftUI

@main
struct AD_BYPASSERApp: App {
    @State private var auth = AuthStore()
    @AppStorage("onboarding.done") private var onboardingDone: Bool = false

    init() {
        // Force Arabic regardless of device language so strings load even when the
        // OS locale is English (e.g. simulator). Set before any view is constructed.
        UserDefaults.standard.set(["ar"], forKey: "AppleLanguages")
        UserDefaults.standard.set("ar_SA", forKey: "AppleLocale")
    }

    var body: some Scene {
        WindowGroup {
            AppRoot(onboardingDone: $onboardingDone)
                .environment(auth)
                .environment(\.locale, Locale(identifier: "ar"))
                .environment(\.layoutDirection, .rightToLeft)
                .tint(.accentColor)
        }
    }
}
