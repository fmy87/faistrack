import SwiftUI

/// A single unlockable milestone — arcade-racer trophy case style rather
/// than a persisted "unlocked" flag in Firestore. Every threshold here is
/// computed fresh from data the app already has (drives, tracks, friends),
/// so there's no extra collection or write path to keep in sync — unlocking
/// is just "does the current data clear the bar," recomputed every time
/// this screen loads.
struct Achievement: Identifiable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let isUnlocked: Bool
}

struct AchievementsView: View {
    @StateObject private var viewModel = AchievementsViewModel()

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            if viewModel.isLoading {
                ProgressView()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.achievements) { achievement in
                            AchievementCard(achievement: achievement)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(NSLocalizedString("achievements.title", comment: ""))
        .task { await viewModel.load() }
    }
}

private struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 10) {
            Text(achievement.icon)
                .font(.system(size: 36))
                .opacity(achievement.isUnlocked ? 1 : 0.25)
            Text(achievement.title)
                .font(.system(size: 14, weight: .bold))
                .multilineTextAlignment(.center)
                .opacity(achievement.isUnlocked ? 1 : 0.6)
            Text(achievement.description)
                .font(.system(size: 11))
                .foregroundColor(.ftTextSecondary)
                .multilineTextAlignment(.center)
            if !achievement.isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.ftTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(12)
        .background(achievement.isUnlocked ? Color.ftCard : Color.ftCard.opacity(0.5))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(achievement.isUnlocked ? Color.ftAccentOrange.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }
}

@MainActor
class AchievementsViewModel: ObservableObject {
    @Published var achievements: [Achievement] = []
    @Published var isLoading = true

    func load() async {
        guard let uid = AuthService.shared.currentUser?.uid else { isLoading = false; return }

        // Reuses StatsViewModel entirely for every drive-derived metric
        // rather than re-fetching and re-computing the same numbers a
        // second time — the only genuinely new data needed here is track
        // creation count, track records held, and friend count.
        let stats = StatsViewModel()
        await stats.load()
        let nightDriveCount = stats.drives.filter { !$0.isPassenger && $0.isNight }.count

        async let tracksCreated = FirebaseService.shared.getTrackCount(ownerUID: uid)
        async let trackRecords = FirebaseService.shared.getTrackRecordCount(uid: uid)
        async let friends = FirebaseService.shared.getFriends(uid: uid)

        let tracksCreatedCount = (try? await tracksCreated) ?? 0
        let trackRecordsCount = (try? await trackRecords) ?? 0
        let friendsCount = (try? await friends)?.count ?? 0

        achievements = [
            Achievement(id: "firstDrive", icon: "🚗",
                        title: NSLocalizedString("achievements.firstDrive", comment: ""),
                        description: NSLocalizedString("achievements.firstDrive.desc", comment: ""),
                        isUnlocked: stats.drivingDriveCount >= 1),
            Achievement(id: "club100", icon: "🏅",
                        title: NSLocalizedString("achievements.club100", comment: ""),
                        description: NSLocalizedString("achievements.club100.desc", comment: ""),
                        isUnlocked: stats.totalDistanceKm >= 100),
            Achievement(id: "club500", icon: "🎖️",
                        title: NSLocalizedString("achievements.club500", comment: ""),
                        description: NSLocalizedString("achievements.club500.desc", comment: ""),
                        isUnlocked: stats.totalDistanceKm >= 500),
            Achievement(id: "nightOwl", icon: "🦉",
                        title: NSLocalizedString("achievements.nightOwl", comment: ""),
                        description: NSLocalizedString("achievements.nightOwl.desc", comment: ""),
                        isUnlocked: nightDriveCount >= 10),
            Achievement(id: "trackMaster", icon: "🏗️",
                        title: NSLocalizedString("achievements.trackMaster", comment: ""),
                        description: NSLocalizedString("achievements.trackMaster.desc", comment: ""),
                        isUnlocked: tracksCreatedCount >= 5),
            Achievement(id: "speedDemon", icon: "⚡",
                        title: NSLocalizedString("achievements.speedDemon", comment: ""),
                        description: NSLocalizedString("achievements.speedDemon.desc", comment: ""),
                        isUnlocked: stats.topSpeedKmh >= 200),
            Achievement(id: "centurion", icon: "💯",
                        title: NSLocalizedString("achievements.centurion", comment: ""),
                        description: NSLocalizedString("achievements.centurion.desc", comment: ""),
                        isUnlocked: stats.drivingDriveCount >= 100),
            Achievement(id: "recordHolder", icon: "👑",
                        title: NSLocalizedString("achievements.recordHolder", comment: ""),
                        description: NSLocalizedString("achievements.recordHolder.desc", comment: ""),
                        isUnlocked: trackRecordsCount >= 1),
            Achievement(id: "onFire", icon: "🔥",
                        title: NSLocalizedString("achievements.onFire", comment: ""),
                        description: NSLocalizedString("achievements.onFire.desc", comment: ""),
                        isUnlocked: stats.onARollStreak >= 7),
            Achievement(id: "socialButterfly", icon: "🦋",
                        title: NSLocalizedString("achievements.socialButterfly", comment: ""),
                        description: NSLocalizedString("achievements.socialButterfly.desc", comment: ""),
                        isUnlocked: friendsCount >= 5)
        ]
        isLoading = false
    }
}
