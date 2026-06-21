import Foundation
import FirebaseFirestore

class LeaderboardService {
    static let shared = LeaderboardService()
    private let db = Firestore.firestore()

    func updateLeaderboard(drive: Drive, uid: String) async {
        guard let user = try? await FirebaseService.shared.getUser(uid: uid) else { return }
        let periods: [LeaderboardPeriod] = [.weekly, .monthly, .allTime]
        for period in periods {
            let key = "\(period.rawValue)_\(uid)"
            let ref = db.collection("leaderboard").document(key)
            let data: [String: Any] = [
                "uid": uid,
                "username": user.username,
                "distance": FieldValue.increment(drive.distance),
                "drives": FieldValue.increment(Int64(1)),
                "hours": FieldValue.increment(Double(drive.duration) / 3600),
                "topSpeed": drive.topSpeed,
                "period": period.rawValue,
                "updatedAt": Timestamp()
            ]
            try? await ref.setData(data, merge: true)
        }
    }

    func getLeaderboard(metric: LeaderboardMetric, period: LeaderboardPeriod, limit: Int = 20) async throws -> [LeaderboardEntry] {
        let snapshot = try await db.collection("leaderboard")
            .whereField("period", isEqualTo: period.rawValue)
            .order(by: metric.rawValue, descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: LeaderboardEntry.self) }
    }
}
