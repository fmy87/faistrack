import SwiftUI

/// Houses everything that isn't one of the four primary tabs (Drives,
/// Tracks, Leaderboard, Friends). Deliberately the only "extra" tab — adding a
/// second one would push the tab bar past 5 items and trigger iOS's own
/// automatic "More" collapse, burying this screen inside a system-generated
/// one instead of showing it directly.
struct MoreView: View {
    // Without this, SwiftUI has no reason to ever re-render MoreView when
    // the signed-in user changes — AdminConfig.isCurrentUserAdmin would
    // only ever be checked once, at whatever moment this view first
    // rendered (which can easily be before Firebase finishes restoring the
    // session on launch), and never again. Observing AuthService directly
    // means this view's body re-runs — and re-checks admin status fresh —
    // any time currentUser changes.
    @ObservedObject private var authService = AuthService.shared
    @State private var showAdminCreateTrack = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        NavigationLink(destination: StatsView()) {
                            ProfileRow(icon: "chart.bar.fill", title: NSLocalizedString("tab.stats", comment: ""))
                        }
                        NavigationLink(destination: GarageView()) {
                            ProfileRow(icon: "wrench.and.screwdriver.fill", title: NSLocalizedString("tab.garage", comment: ""))
                        }
                        NavigationLink(destination: AchievementsView()) {
                            ProfileRow(icon: "rosette", title: NSLocalizedString("achievements.title", comment: ""))
                        }
                        NavigationLink(destination: ProfileView()) {
                            ProfileRow(icon: "person.crop.circle.fill", title: NSLocalizedString("tab.profile", comment: ""))
                        }

                        Divider().background(Color.ftTextSecondary.opacity(0.2)).padding(.vertical, 8)

                        NavigationLink(destination: SettingsView()) {
                            ProfileRow(icon: "gearshape.fill", title: NSLocalizedString("settings.title", comment: ""))
                        }
                        NavigationLink(destination: ManageDrivesView()) {
                            ProfileRow(icon: "car.fill", title: NSLocalizedString("profile.manageDrives", comment: ""))
                        }
                        NavigationLink(destination: ManageTracksView()) {
                            ProfileRow(icon: "flag.checkered", title: NSLocalizedString("profile.manageTracks", comment: ""))
                        }

                        // Only ever visible to the admin account (see
                        // AdminConfig) — everyone else's More screen ends
                        // above this without any sign it exists.
                        if AdminConfig.isCurrentUserAdmin {
                            Divider().background(Color.ftTextSecondary.opacity(0.2)).padding(.vertical, 8)
                            Button(action: { showAdminCreateTrack = true }) {
                                ProfileRow(icon: "wand.and.stars", title: NSLocalizedString("admin.createTrack.title", comment: ""))
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(NSLocalizedString("tab.more", comment: ""))
        }
        .sheet(isPresented: $showAdminCreateTrack) {
            AdminCreateTrackView()
        }
    }
}



