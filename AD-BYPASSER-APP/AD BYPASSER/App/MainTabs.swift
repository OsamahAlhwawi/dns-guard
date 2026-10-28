import SwiftUI

struct MainTabs: View {
    let user: User

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label(NSLocalizedString("tab.dashboard", comment: ""), systemImage: "shield.fill") }

            StatsView()
                .tabItem { Label(NSLocalizedString("tab.stats", comment: ""), systemImage: "chart.bar.fill") }

            if user.isAdmin {
                AdminTabView()
                    .tabItem { Label(NSLocalizedString("tab.admin", comment: ""), systemImage: "person.3.fill") }
            }

            SettingsView()
                .tabItem { Label(NSLocalizedString("tab.settings", comment: ""), systemImage: "gearshape.fill") }
        }
    }
}
