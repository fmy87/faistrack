import Foundation
import FirebaseFirestore

struct Friend: Identifiable, Codable {
    @DocumentID var id: String?
    var uid: String
    var username: String
    var photoURL: String?
    var addedAt: Timestamp = Timestamp()
}

struct FriendRequest: Identifiable, Codable {
    @DocumentID var id: String?
    var fromUid: String
    var fromUsername: String
    var fromPhotoURL: String?
    var createdAt: Timestamp = Timestamp()
}

enum FriendshipStatus {
    case none, friends, requestSent, requestReceived
}
