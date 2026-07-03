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

    /// Undoes a drive's contribution to the leaderboard — called when a
    /// drive gets reclassified as "I was a passenger" after the fact (see
    /// DriveDetailView). distance/drives/hours can simply be subtracted
    /// back out, but topSpeed/longest are *maxes*, and Firestore can't
    /// "un-max" a value — the only correct way to know the new best after
    /// removing this drive is to rescan the user's other drives.
    ///
    /// Known limitation: like `updateLeaderboard`, this treats "weekly" and
    /// "monthly" as one running cumulative bucket per user rather than a
    /// bucket that resets each calendar week/month — the rescan here is
    /// consistent with that existing behavior, not a fix for it. Properly
    /// fixing period resets would need per-week/month document keys and a
    /// scheduled Cloud Function, which is a larger change than this method.
    func reverseContribution(drive: Drive, uid: String) async {
        guard let allDrives = try? await FirebaseService.shared.getDrives(uid: uid, limit: 2000) else { return }
        let remaining = allDrives.filter { !$0.isPassenger && $0.id != drive.id }
        let newTopSpeed = remaining.map(\.topSpeed).max() ?? 0
        let newLongest = remaining.map(\.distance).max() ?? 0

        let periods: [LeaderboardPeriod] = [.weekly, .monthly, .allTime]
        for period in periods {
            let key = "\(period.rawValue)_\(uid)"
            let ref = db.collection("leaderboard").document(key)
            _ = try? await db.runTransaction { transaction, errorPointer -> Any? in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(ref)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                let existingDistance = snapshot.data()?["distance"] as? Double ?? 0
                let existingDrives = snapshot.data()?["drives"] as? Int64 ?? 0
                let existingHours = snapshot.data()?["hours"] as? Double ?? 0

                let data: [String: Any] = [
                    "distance": max(0, existingDistance - drive.distance),
                    "drives": max(0, existingDrives - 1),
                    "hours": max(0, existingHours - Double(drive.duration) / 3600),
                    "topSpeed": newTopSpeed,
                    "longest": newLongest,
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

    func getLeaderboard(metric: LeaderboardMetric, period: LeaderboardPeriod, limit: Int = 20, friendUIDs: [String]? = nil) async throws -> [LeaderboardEntry] {
        var query: Query = db.collection("leaderboard").whereField("period", isEqualTo: period.rawValue)
        if let friendUIDs {
            // Empty friends list means "no results" — Firestore's `in`
            // operator throws if given an empty array rather than matching
            // nothing, so this has to be handled explicitly.
            guard !friendUIDs.isEmpty else { return [] }
            // Firestore's `in` operator caps at 30 values; capping here
            // rather than crashing is the safer failure mode at this app's
            // current scale (nobody has 30+ friends yet).
            query = query.whereField("uid", in: Array(friendUIDs.prefix(30)))
        }
        // Note: combining whereField("uid", in:) with whereField("period", ==)
        // and order(by: metric) requires a Firestore composite index. The
        // first time this runs, Firestore's error includes a direct link to
        // auto-create it in the console — that's expected, not a bug.
        let snapshot = try await query
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

