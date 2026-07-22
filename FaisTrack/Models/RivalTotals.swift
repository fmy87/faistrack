import Foundation

/// A snapshot of one user's all-time leaderboard totals, used to build a
/// head-to-head comparison against a Rival. Backed directly by the same
/// aggregate document LeaderboardService maintains — see
/// FirebaseService.getAllTimeTotals.
struct RivalTotals {
    var distanceKm: Double
    var drives: Int
    var hours: Double
    var topSpeedKmh: Double
    var longestKm: Double
}
