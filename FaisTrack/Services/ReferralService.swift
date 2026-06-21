import Foundation
import FirebaseFirestore

class ReferralService {
    static let shared = ReferralService()
    private let db = Firestore.firestore()

    func generateReferralCode(for uid: String) -> String {
        return "FT-\(uid.prefix(6).uppercased())"
    }

    func applyReferralCode(_ code: String, for uid: String) async throws {
        let snapshot = try await db.collection("referrals")
            .whereField("code", isEqualTo: code).getDocuments()
        guard let doc = snapshot.documents.first,
              let ownerUID = doc.data()["ownerUID"] as? String,
              ownerUID != uid else { return }
        let batch = db.batch()
        let referralRef = db.collection("referrals").document(doc.documentID)
        batch.updateData(["usedBy": FieldValue.arrayUnion([uid])], forDocument: referralRef)
        let ownerRef = db.collection("users").document(ownerUID)
        batch.updateData(["freeDaysEarned": FieldValue.increment(Int64(7))], forDocument: ownerRef)
        try await batch.commit()
    }
}
