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

    /// Fully deletes the account: Firestore data first (still has a valid
    /// session to do this), then the Firebase Auth user itself. Previously
    /// there was no equivalent of this at all — only a "delete data" idea in
    /// the project notes, with no way to remove the Auth account.
    ///
    /// Firebase requires a *recent* sign-in to delete the Auth user; if the
    /// session is old, this throws `.requiresRecentLogin` and the caller
    /// should ask the person to sign out and back in, then retry — this
    /// doesn't attempt a full re-authentication flow itself.
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { throw AuthError.userNotFound }
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

