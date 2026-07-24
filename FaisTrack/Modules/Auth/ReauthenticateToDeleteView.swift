import SwiftUI
import AuthenticationServices

/// Shown when deleteAccount() reports `.requiresRecentLogin` — re-proves
/// identity via whichever provider the account actually signed in with,
/// then automatically retries the deletion. This is what closes the gap
/// AuthService's deleteAccount() docs describe: without this, a stale
/// session had no real recovery path other than "sign out, sign back in,
/// try again" days later, hoping the person remembers they meant to delete
/// their account.
struct ReauthenticateToDeleteView: View {
    let onReauthenticated: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var providerID: String? { AuthService.shared.currentProviderID }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 48)).foregroundColor(.ftAccent)
                    Text(NSLocalizedString("reauth.title", comment: ""))
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text(NSLocalizedString("reauth.subtitle", comment: ""))
                        .font(.system(size: 14)).foregroundColor(.ftTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13)).foregroundColor(.speedRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    Spacer()

                    if providerID == "apple.com" {
                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = AuthService.shared.prepareAppleSignIn()
                        } onCompletion: { result in
                            handleApple(result)
                        }
                        .frame(height: 56).cornerRadius(16)
                        .disabled(isWorking)
                    } else {
                        FTSecondaryButton(title: NSLocalizedString("auth.googleSignIn", comment: "")) {
                            handleGoogle()
                        }
                        .disabled(isWorking)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)

                if isWorking {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("general.cancel", comment: "")) { dismiss() }
                        .disabled(isWorking)
                }
            }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = NSLocalizedString("auth.error.appleCredential", comment: "")
                return
            }
            isWorking = true
            errorMessage = nil
            Task {
                do {
                    try await AuthService.shared.reauthenticateWithApple(credential: credential)
                    isWorking = false
                    onReauthenticated()
                } catch {
                    isWorking = false
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func handleGoogle() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let vc = scene.windows.first?.rootViewController else {
            errorMessage = NSLocalizedString("auth.error.noWindow", comment: "")
            return
        }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await AuthService.shared.reauthenticateWithGoogle(presenting: vc)
                isWorking = false
                onReauthenticated()
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
