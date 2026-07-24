import Foundation
import FirebaseFirestore

/// The subset of a user's profile that's safe for any signed-in stranger to
/// read — mirrored into a separate `publicProfiles/{uid}` collection
/// whenever the underlying FTUser is created or its username changes.
///
/// This exists because Firestore can't restrict which *fields* of a
/// document are readable, only which *documents* are — so the only way to
/// let other users look someone up by username or display their name next
/// to a rival/friend card, without also exposing their email, phone,
/// referral code, rival pick, FCM token, and Pro status to any random
/// signed-in account, is to keep the public subset in its own document
/// entirely. `users/{uid}` itself is now read-restricted to its own owner;
/// every cross-user lookup (search, rival display, friend map pins) reads
/// from here instead.
struct PublicProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var uid: String
    var username: String
    var name: String
    var photoURL: String?
    var isPrivateProfile: Bool = false
}
