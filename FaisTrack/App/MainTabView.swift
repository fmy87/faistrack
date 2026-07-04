import SwiftUI

struct MainTabView: View {
    @ObservedObject private var driveDetection = DriveDetectionService.shared
    // Lets a minimize tap hide the live HUD without touching the actual
    // isDriving state that drives real tracking — the HUD reappears
    // automatically the next time a drive starts.
    @State private var showLiveDriveOverride = true

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
            MoreView()
                .tabItem {
                    Label(NSLocalizedString("tab.more", comment: ""), systemImage: "ellipsis.circle.fill")
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
            Task { await DriveDetectionService.shared.retryPendingDrives() }
        }
        .fullScreenCover(isPresented: Binding(
            get: { driveDetection.isDriving && showLiveDriveOverride },
            set: { newValue in if !newValue { showLiveDriveOverride = false } }
        )) {
            LiveDriveView(onMinimize: { showLiveDriveOverride = false })
        }
        .onChange(of: driveDetection.isDriving) { isDriving in
            if isDriving { showLiveDriveOverride = true }
        }
    }
}




