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
        guard let nonce = currentNonce,
              let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        try await Auth.auth().signIn(with: firebaseCredential)

        // Apple only provides fullName on the very first sign-in ever, which
        // is exactly when we need it to create the profile document.
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        await createProfileIfNeeded(fallbackName: name)
    }

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Google Sign In
    // Uses CLIENT_ID from GoogleService-Info.plist automatically via FirebaseApp
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingClientID
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.invalidCredential
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await Auth.auth().signIn(with: credential)
        await createProfileIfNeeded(fallbackName: result.user.profile?.name ?? "")
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
    /// a recent sign-in. Firebase requires a recent sign-in to delete the
    /// Auth user; that's an undocumented, opaque check, not one that can be
    /// asked in advance — so a stale session used to leave the account in
    /// the worst possible state: Firestore already permanently wiped, but
    /// the Auth account very much still alive and signable-into, now with
    /// no data behind it and no way to get it back. Reordering to delete
    /// Auth first doesn't fix this — it just breaks Firestore cleanup
    /// instead, since Firestore's security rules need `request.auth` to
    /// still be valid to authorize the delete, and it stops being valid the
    /// instant the Auth user is gone. Reauthenticating properly needs a
    /// fresh Apple/Google credential, which lives in the UI layer, not
    /// here — so a real fix belongs in ProfileView's delete flow (redo the
    /// sign-in provider flow right before calling this). Until that lands,
    /// this at least fails *before* touching anything when the session
    /// looks stale, using lastSignInDate as an approximation of Firebase's
    /// actual (undocumented) recent-login window, rather than only
    /// discovering the problem after Firestore data is already gone.
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
            // The heuristic above missed this case — the session was
            // "fresh enough" by our estimate but Firebase's real check
            // still rejected it. Firestore data is already gone at this
            // point, which is exactly the state this function is meant to
            // avoid; there isn't a way to fully close that gap without a
            // reauthentication flow in the UI layer calling this.
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

