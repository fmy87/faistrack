import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = false
    @State private var showSafety = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            SpeedLinesBackground()
            VStack(spacing: 20) {
                Spacer()
                Text("FaisTrack").font(.system(size: 42, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [.ftAccent, .ftAccentOrange],
                                                    startPoint: .leading, endPoint: .trailing))
                Text(NSLocalizedString("auth.tagline", comment: ""))
                    .font(.system(size: 16)).foregroundColor(.ftTextSecondary)
                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.speedRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    // Must set the hashed nonce here and store the raw nonce
                    // in AuthService, or AuthService.signInWithApple will
                    // always fail with "invalid credential".
                    request.nonce = AuthService.shared.prepareAppleSignIn()
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .frame(height: 56).cornerRadius(16)
                .disabled(isLoading)

                FTSecondaryButton(title: NSLocalizedString("auth.googleSignIn", comment: "")) {
                    handleGoogleSignIn()
                }
                .disabled(isLoading)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showSafety) { SafetyView() }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = NSLocalizedString("auth.error.appleCredential", comment: "")
                return
            }
            isLoading = true
            errorMessage = nil
            Task {
                do {
                    try await AuthService.shared.signInWithApple(credential: credential)
                    await MainActor.run {
                        isLoading = false
                        showSafety = true
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func handleGoogleSignIn() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let vc = scene.windows.first?.rootViewController else {
            errorMessage = NSLocalizedString("auth.error.noWindow", comment: "")
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await AuthService.shared.signInWithGoogle(presenting: vc)
                await MainActor.run {
                    isLoading = false
                    showSafety = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
