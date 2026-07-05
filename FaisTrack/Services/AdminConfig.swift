import Foundation

/// Gates admin-only capabilities: manually creating a track without
/// physically driving it, and (via the matching Firestore rule) being the
/// only account that can still delete a published track.
///
/// ⚠️ The UID below was inferred from a Firestore error message you shared
/// earlier in this project, not confirmed directly — verify it matches your
/// actual signed-in account before relying on this. You can find your real
/// UID in Firebase Console → Authentication → Users, next to your account's
/// email. If it doesn't match, update the constant below.
enum AdminConfig {
    static let adminUID = "PA5laQnmppRClBv0A1EXPiULfdy2"

    static var isCurrentUserAdmin: Bool {
        AuthService.shared.currentUser?.uid == adminUID
    }
}
