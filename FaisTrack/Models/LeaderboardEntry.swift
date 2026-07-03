import Foundation
import FirebaseFirestore

struct LeaderboardEntry: Identifiable, Codable {
    @DocumentID var id: String?
    var uid: String
    var username: String
    var photoURL: String?
    var value: Double
    var metric: LeaderboardMetric
    var period: LeaderboardPeriod
    var updatedAt: Timestamp = Timestamp()
}

enum LeaderboardMetric: String, CaseIterable, Codable {
    case distance = "distance"
    case topSpeed = "topSpeed"
    case avgSpeed = "avgSpeed"
    case hours = "hours"
    case drives = "drives"
    case longest = "longest"

    var displayName: String {
        switch self {
        case .distance: return NSLocalizedString("leaderboard.miles", comment: "")
        case .topSpeed: return NSLocalizedString("leaderboard.topSpeed", comment: "")
        case .avgSpeed: return NSLocalizedString("leaderboard.avgSpeed", comment: "")
        case .hours: return NSLocalizedString("leaderboard.hours", comment: "")
        case .drives: return NSLocalizedString("leaderboard.drives", comment: "")
        case .longest: return NSLocalizedString("leaderboard.longest", comment: "")
        }
    }
}

enum LeaderboardPeriod: String, CaseIterable, Codable {
    case weekly = "weekly"
    case monthly = "monthly"
    case allTime = "allTime"

    var displayName: String {
        switch self {
        case .weekly: return NSLocalizedString("leaderboard.weekly", comment: "")
        case .monthly: return NSLocalizedString("leaderboard.monthly", comment: "")
        case .allTime: return NSLocalizedString("leaderboard.allTime", comment: "")
        }
    }
}
