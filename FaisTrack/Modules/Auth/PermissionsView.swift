import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("permissions.title", comment: ""))
                    .font(.system(size: 32, weight: .bold))
                Text(NSLocalizedString("permissions.subtitle", comment: ""))
                    .foregroundColor(.ftTextSecondary)

                PermissionRow(icon: "location.fill",
                              title: NSLocalizedString("permissions.location", comment: ""),
                              desc: NSLocalizedString("permissions.location.desc", comment: ""))
                PermissionRow(icon: "figure.walk",
                              title: NSLocalizedString("permissions.motion", comment: ""),
                              desc: NSLocalizedString("permissions.motion.desc", comment: ""))
                PermissionRow(icon: "bell.fill",
                              title: NSLocalizedString("permissions.notifications", comment: ""),
                              desc: NSLocalizedString("permissions.notifications.desc", comment: ""))
                Spacer()
                FTPrimaryButton(title: NSLocalizedString("permissions.enable", comment: "")) {
                    LocationService.shared.requestPermission()
                    Task { await NotificationService.shared.requestPermission() }
                    appState.currentScreen = .main
                }
            }
            .padding(24)
        }
    }
}

struct PermissionRow: View {
    let icon: String; let title: String; let desc: String
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundColor(.ftAccent)
                .frame(width: 44)
            VStack(alignment: .leading) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(desc).font(.system(size: 13)).foregroundColor(.ftTextSecondary)
            }
        }
    }
}
