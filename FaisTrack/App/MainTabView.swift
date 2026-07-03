import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DrivesView()
                .tabItem {
                    Label(NSLocalizedString("tab.drives", comment: ""), systemImage: "car.fill")
                }
            TracksView()
                .tabItem {
                    Label(NSLocalizedString("tab.tracks", comment: ""), systemImage: "flag.checkered")
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
