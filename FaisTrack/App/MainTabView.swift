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
        .onAppear {
            // Returning users who are already logged in skip straight to
            // .main (see AppState.checkAuthState), bypassing PermissionsView
            // entirely. If location/motion permission was already granted in
            // a previous session, resume monitoring here; if not, these are
            // safe no-ops until the user grants it via Settings.
            LocationService.shared.startUpdating()
            DriveDetectionService.shared.startMonitoring()
        }
    }
}
