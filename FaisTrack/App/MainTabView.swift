import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DrivesView()
                .tabItem {
                    Label(NSLocalizedString("tab.drives", comment: ""), systemImage: "car.fill")
                }
            FriendsView()
                .tabItem {
                    Label(NSLocalizedString("tab.friends", comment: ""), systemImage: "person.2.fill")
                }
            StatsView()
                .tabItem {
                    Label(NSLocalizedString("tab.stats", comment: ""), systemImage: "chart.bar.fill")
                }
            LeaderboardView()
                .tabItem {
                    Label(NSLocalizedString("tab.leaderboard", comment: ""), systemImage: "trophy.fill")
                }
        }
        .accentColor(.ftAccent)
    }
}
