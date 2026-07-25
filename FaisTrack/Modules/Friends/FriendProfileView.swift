import SwiftUI

/// Shown when tapping a friend in the Friends list. Deliberately shows only
/// what's actually safe to read about someone else under the Firestore
/// rules (see FirebaseService/rules notes elsewhere) — their public
/// leaderboard totals, track creation/record counts, and the subset of
/// achievements computable from those same public numbers. It does NOT
/// attempt to reconstruct their full achievement set 1:1 with
/// AchievementsView: several of those (first drive, night owl, centurion,
/// on-a-roll streak, social butterfly) need this person's own private
/// drive history or friends list, neither of which is or should be
/// readable by anyone but them.
struct FriendProfileView: View {
    let friend: Friend
    @StateObject private var viewModel = FriendProfileViewModel()

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            if viewModel.isLoading {
                ProgressView()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        header

                        FTCard {
                            HStack {
                                FTStatBadge(value: String(format: "%.0f km", viewModel.totals.distanceKm),
                                            label: NSLocalizedString("stats.totalDistance", comment: ""))
                                Divider()
                                FTStatBadge(value: "\(viewModel.totals.drives)",
                                            label: NSLocalizedString("drives.dashboard.drives", comment: ""))
                                Divider()
                                FTStatBadge(value: String(format: "%.0f km/h", viewModel.totals.topSpeedKmh),
                                            label: NSLocalizedString("stats.topSpeed", comment: ""))
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("achievements.title", comment: ""))
                                .font(.system(size: 18, weight: .bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                ForEach(viewModel.achievements) { achievement in
                                    AchievementCard(achievement: achievement)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("@\(friend.username)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(friend: friend) }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Circle().fill(Color.ftAccent.opacity(0.25)).frame(width: 72, height: 72)
                .overlay(Text(String(friend.username.prefix(1)).uppercased()).font(.system(size: 28, weight: .bold)))
            Text("@\(friend.username)").font(.system(size: 18, weight: .bold))
            HStack(spacing: 6) {
                Image(systemName: "flag.checkered").font(.system(size: 12))
                Text(String(format: NSLocalizedString("friendProfile.tracksCreated", comment: ""), viewModel.tracksCreated))
                    .font(.system(size: 12))
            }
            .foregroundColor(.ftTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

@MainActor
class FriendProfileViewModel: ObservableObject {
    @Published var totals = RivalTotals(distanceKm: 0, drives: 0, hours: 0, topSpeedKmh: 0, longestKm: 0)
    @Published var tracksCreated = 0
    @Published var achievements: [Achievement] = []
    @Published var isLoading = true

    func load(friend: Friend) async {
        async let totalsResult = FirebaseService.shared.getAllTimeTotals(uid: friend.uid)
        async let tracksCreatedResult = FirebaseService.shared.getTrackCount(ownerUID: friend.uid)
        async let trackRecordsResult = FirebaseService.shared.getTrackRecordCount(uid: friend.uid)

        totals = (try? await totalsResult) ?? totals
        tracksCreated = (try? await tracksCreatedResult) ?? 0
        let trackRecords = (try? await trackRecordsResult) ?? 0

        achievements = [
            Achievement(id: "club100", icon: "🏅",
                        title: NSLocalizedString("achievements.club100", comment: ""),
                        description: NSLocalizedString("achievements.club100.desc", comment: ""),
                        isUnlocked: totals.distanceKm >= 100),
            Achievement(id: "club500", icon: "🎖️",
                        title: NSLocalizedString("achievements.club500", comment: ""),
                        description: NSLocalizedString("achievements.club500.desc", comment: ""),
                        isUnlocked: totals.distanceKm >= 500),
            Achievement(id: "speedDemon", icon: "⚡",
                        title: NSLocalizedString("achievements.speedDemon", comment: ""),
                        description: NSLocalizedString("achievements.speedDemon.desc", comment: ""),
                        isUnlocked: totals.topSpeedKmh >= 200),
            Achievement(id: "trackMaster", icon: "🏗️",
                        title: NSLocalizedString("achievements.trackMaster", comment: ""),
                        description: NSLocalizedString("achievements.trackMaster.desc", comment: ""),
                        isUnlocked: tracksCreated >= 5),
            Achievement(id: "recordHolder", icon: "👑",
                        title: NSLocalizedString("achievements.recordHolder", comment: ""),
                        description: NSLocalizedString("achievements.recordHolder.desc", comment: ""),
                        isUnlocked: trackRecords >= 1)
        ]
        isLoading = false
    }
}
