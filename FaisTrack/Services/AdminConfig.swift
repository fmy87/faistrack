import Foundation

/// Gates admin-only capabilities: manually creating a track without
/// physically driving it, and (via the matching Firestore rule) being the
/// only account that can still delete a published track.
///
/// The UID below is confirmed directly from Firebase Console →
/// Authentication → Users, and corresponds to fmy87@hotmail.com — the one
/// account intended to have admin access. If admin access ever needs to
/// move to a different account, update the constant below and nowhere else.
enum AdminConfig {
    static let adminUID = "PA5laQnmppRCIBv0A1EXPiULfdy2"

    static var isCurrentUserAdmin: Bool {
        AuthService.shared.currentUser?.uid == adminUID
    }
}
