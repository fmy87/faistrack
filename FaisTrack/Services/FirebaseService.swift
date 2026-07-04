import Foundation
import FirebaseFirestore
import CoreLocation

class FirebaseService {
    static let shared = FirebaseService()
    let db = Firestore.firestore()

    // MARK: - User
    func saveUser(_ user: FTUser) async throws {
        try await db.collection("users").document(user.uid).setData(from: user)
    }

    func getUser(uid: String) async throws -> FTUser? {
        let doc = try await db.collection("users").document(uid).getDocument()
        // Critical: .data(as:) throws for a nonexistent document rather than
        // returning nil — without this check, ProfileViewModel.load()'s
        // "if let existing = try await getUser(...)" would throw before it
        // ever reached the `else` branch that recreates a missing profile
        // via ensureUserProfile(). That meant any account with no Firestore
        // document (e.g. one where "Delete Account" wiped Firestore data
        // but Auth deletion failed and left the session signed in) could
        // never self-heal — every load() attempt just threw and left
        // `user` permanently nil, which is exactly what breaks both the
        // private-profile toggle (silently refuses to move) and username
        // saving ("No document to update").
        guard doc.exists else { return nil }
        return try doc.data(as: FTUser.self)
    }

    /// Creates a Firestore profile document for this uid if one doesn't
    /// already exist. Previously nothing in the app ever called this —
    /// after signing in with Apple/Google, no `users/{uid}` document was
    /// ever created, so every profile read returned nil forever (breaking
    /// Instagram saving, leaderboard entries, and anywhere a username was
    /// looked up).
    func ensureUserProfile(uid: String, name: String, email: String?) async throws -> FTUser {
        if let existing = try await getUser(uid: uid) {
            return existing
        }
        let seed = name.isEmpty ? (email ?? "driver") : name
        let username = try await generateUniqueUsername(from: seed)
        let newUser = FTUser(
            uid: uid,
            name: name.isEmpty ? "Driver" : name,
            username: username,
            email: email,
            referralCode: Self.generateReferralCode()
        )
        try await saveUser(newUser)
        return newUser
    }

    /// Checks whether a username is free to use. Usernames are stored
    /// lowercased (see generateUsername/updateUsername), so comparisons are
    /// case-insensitive — "Jake" and "jake" are treated as the same name,
    /// which is what people expect from a username system.
    func isUsernameAvailable(_ username: String, excludingUid: String? = nil) async throws -> Bool {
        let lowered = username.lowercased()
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: lowered)
            .limit(to: 5)
            .getDocuments()
        return !snapshot.documents.contains { $0.documentID != excludingUid }
    }

    /// Lets a user set or change their own username, enforced unique here
    /// (there's no Firestore rule that can guarantee uniqueness on its own —
    /// that needs an application-level check like this one, done right
    /// before the write so the race window is as small as practical).
    func updateUsername(uid: String, newUsername: String) async throws {
        let lowered = newUsername.lowercased()
        guard try await isUsernameAvailable(lowered, excludingUid: uid) else {
            throw FirebaseServiceError.usernameTaken
        }
        // setData(merge:) rather than updateData() — updateData() throws
        // "No document to update" outright if the document doesn't exist
        // yet, which is exactly the failure mode this hit for an account
        // whose profile document was missing (see getUser() fix above for
        // the actual root cause). merge:true is safe here regardless: it
        // updates just the username field on an existing doc, or creates a
        // new doc with just that field set if one doesn't exist at all.
        try await db.collection("users").document(uid).setData(["username": lowered], merge: true)
    }

    /// Previously the auto-generated username (name + random 4-digit
    /// suffix) was never checked against existing usernames at all — with
    /// a common first name, the ~9000-value suffix space collides often
    /// enough (birthday-paradox effect) to be a real problem now that
    /// usernames back both friend search and leaderboards. This retries
    /// with a fresh random suffix until an actually-free one is found.
    private func generateUniqueUsername(from seed: String) async throws -> String {
        for _ in 0..<10 {
            let candidate = Self.generateUsername(from: seed)
            if try await isUsernameAvailable(candidate) {
                return candidate
            }
        }
        // Exceedingly unlikely fallback after 10 collisions in a row, but
        // a UUID-derived suffix can't practically collide either way.
        return "driver\(UUID().uuidString.prefix(8))".lowercased()
    }

    private static func generateUsername(from seed: String) -> String {
        let base = seed.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        let trimmedBase = String(base.prefix(12))
        let suffix = String(Int.random(in: 1000...9999))
        return trimmedBase.isEmpty ? "driver\(suffix)" : "\(trimmedBase)\(suffix)"
    }

    private static func generateReferralCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // no ambiguous chars (0/O, 1/I)
        return String((0..<6).map { _ in letters.randomElement()! })
    }

    // MARK: - Cars
    func saveCar(_ car: Car, uid: String) async throws {
        let ref = car.id == nil
            ? db.collection("users").document(uid).collection("cars").document()
            : db.collection("users").document(uid).collection("cars").document(car.id!)
        try await ref.setData(from: car)
    }

    func getCars(uid: String) async throws -> [Car] {
        let snapshot = try await db.collection("users").document(uid)
            .collection("cars")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Car.self) }
    }

    func deleteCar(carId: String, uid: String) async throws {
        try await db.collection("users").document(uid)
            .collection("cars").document(carId).delete()
    }

    func setActiveCar(carId: String, uid: String) async throws {
        let cars = try await getCars(uid: uid)
        let batch = db.batch()
        for car in cars {
            guard let id = car.id else { continue }
            let ref = db.collection("users").document(uid).collection("cars").document(id)
            batch.updateData(["isActive": id == carId], forDocument: ref)
        }
        try await batch.commit()
    }

    // MARK: - Drives
    func saveDrive(_ drive: Drive, uid: String) async throws {
        let ref = drive.id == nil
            ? db.collection("users").document(uid).collection("drives").document()
            : db.collection("users").document(uid).collection("drives").document(drive.id!)
        try await ref.setData(from: drive)
    }

    func getDrives(uid: String, limit: Int = 20) async throws -> [Drive] {
        let snapshot = try await db.collection("users").document(uid)
            .collection("drives")
            .order(by: "startTime", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Drive.self) }
    }

    func deleteDrive(driveId: String, uid: String) async throws {
        try await db.collection("users").document(uid)
            .collection("drives").document(driveId).delete()
    }

    // MARK: - Tracks
    /// Creates a new Track directly from a manually-recorded run (see
    /// TrackCreationService) — as opposed to publishTrack(from:), which
    /// derives one from an already-completed automatic Drive.
    func createTrack(_ track: Track) async throws -> String {
        let ref = db.collection("tracks").document()
        try await ref.setData(from: track)
        return ref.documentID
    }

    /// Publishes a drive's recorded route as a competable Track. The start
    /// and end points come from the decoded polyline (the drive model only
    /// stores place-name strings, not raw coordinates).
    func publishTrack(from drive: Drive, coordinates: [CLLocationCoordinate2D], ownerUID: String, ownerUsername: String) async throws -> String {
        guard let first = coordinates.first, let last = coordinates.last,
              let encoded = drive.polylineEncoded else {
            throw FirebaseServiceError.invalidTrack
        }
        let name: String
        if let start = drive.startPlaceName, let end = drive.endPlaceName {
            name = "\(start) → \(end)"
        } else {
            name = NSLocalizedString("tracks.defaultName", comment: "")
        }
        let track = Track(
            ownerUID: ownerUID,
            ownerUsername: ownerUsername,
            name: name,
            startLatitude: first.latitude,
            startLongitude: first.longitude,
            endLatitude: last.latitude,
            endLongitude: last.longitude,
            distance: drive.distance * 1000,
            polylineEncoded: encoded
        )
        let ref = db.collection("tracks").document()
        try await ref.setData(from: track)
        return ref.documentID
    }

    func getTracks(limit: Int = 50) async throws -> [Track] {
        let snapshot = try await db.collection("tracks")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Track.self) }
    }

    func saveTrackResult(_ result: TrackResult) async throws {
        guard !result.trackId.isEmpty else { return }
        let ref = db.collection("tracks").document(result.trackId)
            .collection("results").document()
        try await ref.setData(from: result)

        // Update the track's best time if this attempt beats it.
        // (Simple read-then-write; fine at this scale, could be a
        // transaction later if concurrent finishes become common.)
        let trackRef = db.collection("tracks").document(result.trackId)
        let trackDoc = try await trackRef.getDocument()
        let currentBest = trackDoc.data()?["bestTime"] as? Double
        var updates: [String: Any] = ["attemptCount": FieldValue.increment(Int64(1))]
        if currentBest == nil || result.duration < currentBest! {
            updates["bestTime"] = result.duration
            updates["bestTimeUsername"] = result.username
            // bestTimeUid lets the "record broken" Cloud Function (see
            // functions/index.js) look up the *previous* holder's fcmToken
            // and notify them — this write alone doesn't send anything.
            updates["bestTimeUid"] = result.uid
            // Carried onto the Track itself (rather than requiring a
            // separate fetch of the winning TrackResult) so the share card
            // can show the record holder's top speed and car with no extra
            // round trip.
            updates["bestTimeTopSpeed"] = result.topSpeed
            if let carName = result.carName {
                updates["bestTimeCarName"] = carName
            }
        }
        try await trackRef.updateData(updates)
    }

    func getTrackLeaderboard(trackId: String, limit: Int = 20) async throws -> [TrackResult] {
        let snapshot = try await db.collection("tracks").document(trackId)
            .collection("results")
            .order(by: "duration", descending: false)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: TrackResult.self) }
    }

    /// Deletes a track and cascade-deletes its "results" subcollection first
    /// — Firestore's client SDK has no recursive delete, so previously those
    /// documents were left behind as permanent orphans every time a track
    /// was deleted.
    func deleteTrack(trackId: String) async throws {
        let resultsRef = db.collection("tracks").document(trackId).collection("results")
        try await deleteAllDocuments(in: resultsRef)
        try await db.collection("tracks").document(trackId).delete()
    }

    /// Deletes every document in a collection in batches of 400 (Firestore's
    /// batch limit is 500 writes; 400 leaves headroom). Used anywhere a
    /// subcollection needs a full wipe — track results, and every
    /// subcollection under a deleted user account.
    private func deleteAllDocuments(in collection: CollectionReference) async throws {
        let snapshot = try await collection.getDocuments()
        var batch = db.batch()
        var opCount = 0
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
            opCount += 1
            if opCount == 400 {
                try await batch.commit()
                batch = db.batch()
                opCount = 0
            }
        }
        if opCount > 0 { try await batch.commit() }
    }

    // MARK: - Friends
    /// Prefix search on username. Firestore has no native substring search;
    /// this relies on lexicographic range querying, which only matches from
    /// the start of the username (not the middle) — acceptable for a
    /// "search by username" field rather than a fuzzy people-search.
    func searchUsers(query: String, excludingUid: String, limit: Int = 20) async throws -> [FTUser] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !lowered.isEmpty else { return [] }
        let snapshot = try await db.collection("users")
            .order(by: "username")
            .start(at: [lowered])
            .end(at: [lowered + "\u{f8ff}"])
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents
            .compactMap { try? $0.data(as: FTUser.self) }
            .filter { $0.uid != excludingUid }
    }

    func sendFriendRequest(from: FTUser, toUid: String) async throws {
        let ref = db.collection("users").document(toUid)
            .collection("friendRequests").document(from.uid)
        let request = FriendRequest(fromUid: from.uid, fromUsername: from.username, fromPhotoURL: from.photoURL)
        try ref.setData(from: request)
    }

    func getFriendRequests(uid: String) async throws -> [FriendRequest] {
        let snapshot = try await db.collection("users").document(uid)
            .collection("friendRequests")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FriendRequest.self) }
    }

    /// Writes the friendship to both users' `friends` subcollections and
    /// removes the request in one batch, so the two sides never end up
    /// inconsistent (e.g. accepted on my side but not showing on theirs).
    func acceptFriendRequest(uid: String, myUsername: String, myPhotoURL: String?, request: FriendRequest) async throws {
        let batch = db.batch()
        let myFriendRef = db.collection("users").document(uid).collection("friends").document(request.fromUid)
        let theirFriendRef = db.collection("users").document(request.fromUid).collection("friends").document(uid)
        let requestRef = db.collection("users").document(uid).collection("friendRequests").document(request.fromUid)

        try batch.setData(from: Friend(uid: request.fromUid, username: request.fromUsername, photoURL: request.fromPhotoURL), forDocument: myFriendRef)
        try batch.setData(from: Friend(uid: uid, username: myUsername, photoURL: myPhotoURL), forDocument: theirFriendRef)
        batch.deleteDocument(requestRef)
        try await batch.commit()
    }

    func declineFriendRequest(uid: String, fromUid: String) async throws {
        try await db.collection("users").document(uid).collection("friendRequests").document(fromUid).delete()
    }

    func getFriends(uid: String) async throws -> [Friend] {
        let snapshot = try await db.collection("users").document(uid).collection("friends")
            .order(by: "addedAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Friend.self) }
    }

    func removeFriend(uid: String, friendUid: String) async throws {
        let batch = db.batch()
        batch.deleteDocument(db.collection("users").document(uid).collection("friends").document(friendUid))
        batch.deleteDocument(db.collection("users").document(friendUid).collection("friends").document(uid))
        try await batch.commit()
    }

    /// Used to decide what the "Add" button in search results should say —
    /// without this, tapping Add repeatedly would create duplicate pending
    /// request documents.
    func friendshipStatus(myUid: String, otherUid: String) async throws -> FriendshipStatus {
        let friendDoc = try await db.collection("users").document(myUid).collection("friends").document(otherUid).getDocument()
        if friendDoc.exists { return .friends }
        let sentDoc = try await db.collection("users").document(otherUid).collection("friendRequests").document(myUid).getDocument()
        if sentDoc.exists { return .requestSent }
        let receivedDoc = try await db.collection("users").document(myUid).collection("friendRequests").document(otherUid).getDocument()
        if receivedDoc.exists { return .requestReceived }
        return .none
    }

    // MARK: - Account deletion
    /// Deletes everything tied to an account: profile, cars, drives,
    /// leaderboard entries, friendships on both sides, and every track this
    /// user owns (with its results, via the same cascade as deleteTrack).
    /// Does NOT delete the Firebase Auth account itself — see
    /// AuthService.deleteAccount(), which calls this first and then deletes
    /// the Auth user, since the Auth SDK call needs to happen client-side
    /// with a valid session.
    func deleteAllUserData(uid: String) async throws {
        let userRef = db.collection("users").document(uid)

        try await deleteAllDocuments(in: userRef.collection("cars"))
        try await deleteAllDocuments(in: userRef.collection("drives"))
        try await deleteAllDocuments(in: userRef.collection("friendRequests"))

        // Remove this uid from every friend's own friends subcollection
        // first (while we can still read who they are), then delete our
        // own friends subcollection.
        if let myFriends = try? await getFriends(uid: uid) {
            for friend in myFriends {
                try? await db.collection("users").document(friend.uid)
                    .collection("friends").document(uid).delete()
            }
        }
        try await deleteAllDocuments(in: userRef.collection("friends"))

        for period in LeaderboardPeriod.allCases {
            try? await db.collection("leaderboard").document("\(period.rawValue)_\(uid)").delete()
        }

        if let ownedTracks = try? await db.collection("tracks").whereField("ownerUID", isEqualTo: uid).getDocuments() {
            for doc in ownedTracks.documents {
                try? await deleteTrack(trackId: doc.documentID)
            }
        }

        try await userRef.delete()
    }

    // MARK: - Live driving status
    /// Deliberately a separate top-level collection rather than fields on
    /// `users/{uid}` — that document's security rule only lets the owner
    /// read/write it at all, and loosening that just for these two fields
    /// would mean touching a rule that everything else depends on. A
    /// dedicated collection keeps the "friends can read this, only I can
    /// write it" rule scoped to exactly the data it's meant for.
    ///
    /// `coordinate` is optional and omitted from the write entirely when
    /// nil (e.g. drive just ended, or Ghost Mode is on) — using `merge` with
    /// a coordinate present updates it, but not writing the fields at all
    /// when there's nothing to share is preferable to writing stale (0,0)
    /// values that could be mistaken for a real location.
    func updateLiveStatus(uid: String, isDriving: Bool, coordinate: CLLocationCoordinate2D? = nil) async {
        var data: [String: Any] = [
            "uid": uid,
            "isDriving": isDriving,
            "updatedAt": Timestamp()
        ]
        if let coordinate {
            data["latitude"] = coordinate.latitude
            data["longitude"] = coordinate.longitude
        }
        try? await db.collection("liveStatus").document(uid).setData(data, merge: true)
    }

    /// Firestore's `in` operator caps at 30 values and throws on an empty
    /// array — both handled here so callers can just pass a friends list
    /// straight through regardless of size.
    func getFriendsLiveStatus(friendUIDs: [String]) async throws -> [String: Bool] {
        guard !friendUIDs.isEmpty else { return [:] }
        let snapshot = try await db.collection("liveStatus")
            .whereField(FieldPath.documentID(), in: Array(friendUIDs.prefix(30)))
            .getDocuments()
        var result: [String: Bool] = [:]
        for doc in snapshot.documents {
            result[doc.documentID] = doc.data()["isDriving"] as? Bool ?? false
        }
        return result
    }

    /// Richer version of getFriendsLiveStatus for map display — only
    /// returns friends who are both currently driving AND have a location
    /// present (Ghost Mode / a drive that just ended means no lat/lng gets
    /// written at all, so those friends are naturally excluded here rather
    /// than needing a separate check).
    func getFriendsLiveLocations(friendUIDs: [String]) async throws -> [FriendMapPin] {
        guard !friendUIDs.isEmpty else { return [] }
        let snapshot = try await db.collection("liveStatus")
            .whereField(FieldPath.documentID(), in: Array(friendUIDs.prefix(30)))
            .getDocuments()
        var pins: [FriendMapPin] = []
        for doc in snapshot.documents {
            let data = doc.data()
            guard data["isDriving"] as? Bool == true,
                  let lat = data["latitude"] as? Double,
                  let lng = data["longitude"] as? Double else { continue }
            let username = (try? await getUser(uid: doc.documentID))?.username ?? "?"
            pins.append(FriendMapPin(id: doc.documentID, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), username: username))
        }
        return pins
    }

    // MARK: - Photo Upload (disabled until Firebase Storage is enabled on Blaze plan)
    func uploadCarPhoto(uid: String, carId: String, imageData: Data) async throws -> String {
        // Storage requires Blaze plan — store photo locally for now
        // TODO: enable when upgrading to Blaze
        throw FirebaseServiceError.storageNotEnabled
    }
}

enum FirebaseServiceError: LocalizedError {
    case storageNotEnabled
    case invalidTrack
    case usernameTaken
    var errorDescription: String? {
        switch self {
        case .storageNotEnabled:
            return NSLocalizedString("firebase.error.storageNotEnabled", comment: "")
        case .invalidTrack:
            return NSLocalizedString("firebase.error.invalidTrack", comment: "")
        case .usernameTaken:
            return NSLocalizedString("firebase.error.usernameTaken", comment: "")
        }
    }
}







