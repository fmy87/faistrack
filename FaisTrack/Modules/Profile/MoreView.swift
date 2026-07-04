import SwiftUI

/// Houses app settings and data-management screens that don't belong on
/// the Profile tab (which is now just identity/account: name, privacy,
/// sign out, delete account). Split out so Profile doesn't turn into a
/// junk drawer of unrelated settings as the app grows.
struct MoreView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        NavigationLink(destination: SettingsView()) {
                            ProfileRow(icon: "gearshape.fill", title: NSLocalizedString("settings.title", comment: ""))
                        }
                        NavigationLink(destination: ManageDrivesView()) {
                            ProfileRow(icon: "car.fill", title: NSLocalizedString("profile.manageDrives", comment: ""))
                        }
                        NavigationLink(destination: ManageTracksView()) {
                            ProfileRow(icon: "flag.checkered", title: NSLocalizedString("profile.manageTracks", comment: ""))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(NSLocalizedString("tab.more", comment: ""))
        }
    }
}
