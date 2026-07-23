import SwiftUI

/// A one-time (per version) "what's new" sheet highlighting recently added
/// features — with this much added lately (Rival System, Achievements,
/// Ghost Racing, Track Medals, speed heatmaps), none of it had any in-app
/// discovery mechanism otherwise; someone would only ever find these by
/// stumbling into the right screen on their own.
struct WhatsNewView: View {
    @Environment(\.dismiss) var dismiss

    /// Bump this when there's a new batch of features worth announcing —
    /// changing it shows the sheet again to everyone, including people who
    /// already saw an earlier version. Same versioned-flag pattern as the
    /// intro video's first-launch gating.
    private static let currentVersion = 1
    private static let seenVersionKey = "whatsNewSeenVersion"

    static var hasUnseenContent: Bool {
        UserDefaults.standard.integer(forKey: seenVersionKey) < currentVersion
    }

    static func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: seenVersionKey)
    }

    private let features: [(icon: String, titleKey: String, descKey: String)] = [
        ("flag.2.crossed.fill", "whatsNew.rival.title", "whatsNew.rival.desc"),
        ("rosette", "whatsNew.achievements.title", "whatsNew.achievements.desc"),
        ("circle.dashed", "whatsNew.ghost.title", "whatsNew.ghost.desc"),
        ("flame.fill", "whatsNew.heatmap.title", "whatsNew.heatmap.desc"),
        ("trophy.fill", "whatsNew.legend.title", "whatsNew.legend.desc")
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                            HStack(spacing: 14) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: 22))
                                    .foregroundColor(.ftAccent)
                                    .frame(width: 44, height: 44)
                                    .background(Color.ftAccent.opacity(0.12))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(NSLocalizedString(feature.titleKey, comment: ""))
                                        .font(.system(size: 16, weight: .bold))
                                    Text(NSLocalizedString(feature.descKey, comment: ""))
                                        .font(.system(size: 13)).foregroundColor(.ftTextSecondary)
                                }
                                Spacer()
                            }
                        }

                        FTPrimaryButton(title: NSLocalizedString("whatsNew.gotIt", comment: "")) {
                            dismiss()
                        }
                        .padding(.top, 12)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(NSLocalizedString("whatsNew.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
