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
                    Label(NSLocalizedString("tab.tracks", comment: ""), systemImage: "map.fill")
                }
            GarageView()
                .tabItem {
                    Label(NSLocalizedString("tab.garage", comment: ""), systemImage: "wrench.and.screwdriver.fill")
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
            ProfileView()
                .tabItem {
                    Label(NSLocalizedString("tab.profile", comment: ""), systemImage: "person.crop.circle.fill")
                }
        }
        .accentColor(.ftAccent)
    }
}
