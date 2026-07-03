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

            // distance/drives/hours accumulate normally, but topSpeed and
            // longest are personal *bests* — FieldValue only supports
            // increment, not max, so those two need a read-modify-write
            // inside a transaction instead of being blindly overwritten
            // (which previously made "top speed" reflect only the most
            // recent drive rather than the actual best one for the period).
            _ = try? await db.runTransaction { transaction, errorPointer -> Any? in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(ref)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                let existingTopSpeed = snapshot.data()?["topSpeed"] as? Double ?? 0
                let existingLongest = snapshot.data()?["longest"] as? Double ?? 0
                let existingDistance = snapshot.data()?["distance"] as? Double ?? 0
                let existingDrives = snapshot.data()?["drives"] as? Int64 ?? 0
                let existingHours = snapshot.data()?["hours"] as? Double ?? 0

                let data: [String: Any] = [
                    "uid": uid,
                    "username": user.username,
                    "photoURL": user.photoURL as Any,
                    "distance": existingDistance + drive.distance,
                    "drives": existingDrives + 1,
                    "hours": existingHours + Double(drive.duration) / 3600,
                    "topSpeed": max(existingTopSpeed, drive.topSpeed),
                    "longest": max(existingLongest, drive.distance),
                    "period": period.rawValue,
                    "updatedAt": Timestamp()
                ]
                transaction.setData(data, forDocument: ref, merge: true)
                return nil
            }
        }
    }

    /// Builds a LeaderboardEntry from a raw Firestore document for a given
    /// metric. Each metric (distance/drives/hours/topSpeed/longest) is
    /// stored under its own field name rather than a shared "value" field,
    /// so a plain `data(as: LeaderboardEntry.self)` decode would always fail
    /// to find "value" and silently produce nothing — this maps the right
    /// field explicitly instead.
    private func makeEntry(from doc: QueryDocumentSnapshot, metric: LeaderboardMetric, period: LeaderboardPeriod) -> LeaderboardEntry? {
        let data = doc.data()
        guard let uid = data["uid"] as? String,
              let username = data["username"] as? String else { return nil }
        let rawValue = data[metric.rawValue]
        let value: Double
        if let d = rawValue as? Double {
            value = d
        } else if let n = rawValue as? NSNumber {
            value = n.doubleValue
        } else {
            value = 0
        }
        return LeaderboardEntry(
            id: doc.documentID, uid: uid, username: username,
            photoURL: data["photoURL"] as? String, value: value, metric: metric, period: period
        )
    }

    func getLeaderboard(metric: LeaderboardMetric, period: LeaderboardPeriod, limit: Int = 20) async throws -> [LeaderboardEntry] {
        let snapshot = try await db.collection("leaderboard")
            .whereField("period", isEqualTo: period.rawValue)
            .order(by: metric.rawValue, descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { makeEntry(from: $0, metric: metric, period: period) }
    }

    /// Looks up the current user's own entry for a metric/period even if
    /// they're outside the top `limit` results, so the "Your Rank" row can
    /// still be shown accurately.
    func getUserRank(uid: String, metric: LeaderboardMetric, period: LeaderboardPeriod) async throws -> (rank: Int, entry: LeaderboardEntry)? {
        let allSnapshot = try await db.collection("leaderboard")
            .whereField("period", isEqualTo: period.rawValue)
            .order(by: metric.rawValue, descending: true)
            .getDocuments()
        let entries = allSnapshot.documents.compactMap { makeEntry(from: $0, metric: metric, period: period) }
        guard let index = entries.firstIndex(where: { $0.uid == uid }) else { return nil }
        return (index + 1, entries[index])
    }
}
