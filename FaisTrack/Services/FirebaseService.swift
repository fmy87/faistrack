import Foundation
import FirebaseFirestore

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

    // MARK: - Photo Upload (disabled until Firebase Storage is enabled on Blaze plan)
    func uploadCarPhoto(uid: String, carId: String, imageData: Data) async throws -> String {
        // Storage requires Blaze plan — store photo locally for now
        // TODO: enable when upgrading to Blaze
        throw FirebaseServiceError.storageNotEnabled
    }
}

enum FirebaseServiceError: LocalizedError {
    case storageNotEnabled
    var errorDescription: String? {
        switch self {
        case .storageNotEnabled:
            return "Photo upload will be available in a future update."
        }
    }
}
