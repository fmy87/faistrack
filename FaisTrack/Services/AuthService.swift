import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()
    @Published var currentUser: FirebaseAuth.User?
    private var currentNonce: String?

    var isLoggedIn: Bool { currentUser != nil }

    override init() {
        super.init()
        currentUser = Auth.auth().currentUser
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
        }
    }

    // MARK: - Apple Sign In
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        let firebaseCredential = try appleFirebaseCredential(from: credential)
        try await Auth.auth().signIn(with: firebaseCredential)

        // Apple only provides fullName on the very first sign-in ever, which
        // is exactly when we need it to create the profile document.
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        await createProfileIfNeeded(fallbackName: name)
    }

    /// Re-proves identity with a *fresh* Apple credential right before a
    /// sensitive operation (currently: account deletion) that Firebase
    /// would otherwise reject with `.requiresRecentLogin`. Shares the same
    /// credential-building logic as sign-in — reauthenticating is really
    /// just "sign in again, but against the existing user instead of
    /// starting a new session."
    func reauthenticateWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let user = Auth.auth().currentUser else { throw AuthError.userNotFound }
        let firebaseCredential = try appleFirebaseCredential(from: credential)
        try await user.reauthenticate(with: firebaseCredential)
    }

    private func appleFirebaseCredential(from credential: ASAuthorizationAppleIDCredential) throws -> OAuthCredential {
        guard let nonce = currentNonce,
              let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        return OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
    }

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Google Sign In
    // Uses CLIENT_ID from GoogleService-Info.plist automatically via FirebaseApp
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        let credential = try await googleFirebaseCredential(presenting: viewController)
        try await Auth.auth().signIn(with: credential)
        await createProfileIfNeeded(fallbackName: Auth.auth().currentUser?.displayName ?? "")
    }

    /// Same reasoning as reauthenticateWithApple above, for the Google
    /// provider — re-runs the actual Google sign-in sheet to get a fresh
    /// credential, since there's no way to silently "refresh" proof of
    /// identity without the person doing something in the UI.
    func reauthenticateWithGoogle(presenting viewController: UIViewController) async throws {
        guard let user = Auth.auth().currentUser else { throw AuthError.userNotFound }
        let credential = try await googleFirebaseCredential(presenting: viewController)
        try await user.reauthenticate(with: credential)
    }

    private func googleFirebaseCredential(presenting viewController: UIViewController) async throws -> AuthCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingClientID
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.invalidCredential
        }
        return GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
    }

    /// Which provider the current session originally signed in with —
    /// drives which reauthentication button the delete-account flow
    /// should show, since re-proving identity has to go through whichever
    /// provider actually issued this account's credential.
    var currentProviderID: String? {
        Auth.auth().currentUser?.providerData.first?.providerID
    }

    /// Creates the Firestore user profile document on first sign-in.
    /// This used to never happen at all — see FirebaseService.ensureUserProfile.
    /// Failure here doesn't block sign-in (the user is still authenticated);
    /// ProfileView also self-heals this on next load as a safety net.
    private func createProfileIfNeeded(fallbackName: String) async {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        let name = firebaseUser.displayName?.isEmpty == false ? firebaseUser.displayName! : fallbackName
        _ = try? await FirebaseService.shared.ensureUserProfile(
            uid: firebaseUser.uid,
            name: name,
            email: firebaseUser.email
        )
    }

    // MARK: - Handle Google Sign-In URL redirect
    func handleURL(_ url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }

    /// Fully deletes the account: Firestore data first (deleting a user's
    /// own subcollections requires an authenticated session, so this has
    /// to happen before the Auth user is gone), then the Firebase Auth
    /// user itself.
    ///
    /// This used to delete Firestore data unconditionally, then attempt
    /// the Auth deletion and only find out *afterward* whether it needed
    /// a recent sign-in — a stale session could leave the account in the
    /// worst possible state: Firestore already permanently wiped, but the
    /// Auth account still alive and signable-into, now with no data behind
    /// it. Two layers guard against that now: a `lastSignInDate` heuristic
    /// bails out here before touching anything if the session looks stale,
    /// and ProfileView catches `.requiresRecentLogin` (whether this
    /// heuristic catches it or Firebase's own check does) and presents
    /// reauthenticateWithApple/Google to get a fresh credential, then
    /// retries this whole method — so even a missed case recovers cleanly
    /// instead of losing data.
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { throw AuthError.userNotFound }
        if let lastSignIn = user.metadata.lastSignInDate,
           Date().timeIntervalSince(lastSignIn) > 4 * 60 {
            throw AuthError.requiresRecentLogin
        }
        let uid = user.uid
        try await FirebaseService.shared.deleteAllUserData(uid: uid)
        do {
            try await user.delete()
        } catch let error as NSError where error.code == AuthErrorCode.requiresRecentLogin.rawValue {
            throw AuthError.requiresRecentLogin
        }
    }

    // MARK: - Helpers
    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hash = SHA256.hash(data: inputData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

enum AuthError: Error, LocalizedError {
    case invalidCredential
    case userNotFound
    case missingClientID
    case requiresRecentLogin

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return NSLocalizedString("auth.error.invalidCredential", comment: "")
        case .userNotFound: return NSLocalizedString("auth.error.userNotFound", comment: "")
        case .missingClientID: return NSLocalizedString("auth.error.missingClientID", comment: "")
        case .requiresRecentLogin: return NSLocalizedString("auth.error.requiresRecentLogin", comment: "")
        }
    }
}

