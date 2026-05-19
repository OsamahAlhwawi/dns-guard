import SwiftUI

struct MainTabs: View {
    let user: User

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label(String(localized: "tab.dashboard"), systemImage: "shield.fill") }

            StatsView()
                .tabItem { Label(String(localized: "tab.stats"), systemImage: "chart.bar.fill") }

            if user.isAdmin {
                AdminTabView()
                    .tabItem { Label(String(localized: "tab.admin"), systemImage: "person.3.fill") }
            }

            SettingsView()
                .tabItem { Label(String(localized: "tab.settings"), systemImage: "gearshape.fill") }
        }
    }
}
