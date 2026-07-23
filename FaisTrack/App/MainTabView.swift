import SwiftUI

struct MainTabView: View {
    @ObservedObject private var driveDetection = DriveDetectionService.shared
    // Lets a minimize tap hide the live HUD without touching the actual
    // isDriving state that drives real tracking — the HUD reappears
    // automatically the next time a drive starts.
    @State private var showLiveDriveOverride = true
    @State private var showWhatsNew = false

    var body: some View {
        ZStack {
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

            // Mounted once here, at the root of the authenticated app, so a
            // toast can appear over any tab or screen — not just wherever
            // it happened to be triggered from.
            ToastOverlayView()
        }
        .onAppear {
            // Returning users who are already logged in skip straight to
            // .main (see AppState.checkAuthState), bypassing PermissionsView
            // entirely. If location/motion permission was already granted in
            // a previous session, resume monitoring here; if not, these are
            // safe no-ops until the user grants it via Settings.
            LocationService.shared.startUpdating()
            DriveDetectionService.shared.startMonitoring()
            Task { await DriveDetectionService.shared.retryPendingDrives() }

            // Shown once per app version's feature set — gated by its own
            // key (see WhatsNewView) so bumping whatsNewVersion later shows
            // a fresh one to everyone, including people who saw an older one.
            if WhatsNewView.hasUnseenContent {
                showWhatsNew = true
            }
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
        .sheet(isPresented: $showWhatsNew, onDismiss: { WhatsNewView.markSeen() }) {
            WhatsNewView()
        }
    }
}





