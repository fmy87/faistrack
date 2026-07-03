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
        return try doc.data(as: FTUser.self)
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

    // MARK: - Tracks
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
    var errorDescription: String? {
        switch self {
        case .storageNotEnabled:
            return "Photo upload will be available in a future update."
        case .invalidTrack:
            return "This drive doesn't have a valid route to publish as a track."
        }
    }
}
