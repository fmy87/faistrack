import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = false
    @State private var showSafety = false

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Text("FaisTrack").font(.system(size: 42, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [.ftAccent, .ftAccentOrange],
                                                    startPoint: .leading, endPoint: .trailing))
                Text(NSLocalizedString("auth.tagline", comment: ""))
                    .font(.system(size: 16)).foregroundColor(.ftTextSecondary)
                Spacer()
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .frame(height: 56).cornerRadius(16)

                FTSecondaryButton(title: NSLocalizedString("auth.googleSignIn", comment: "")) {
                    handleGoogleSignIn()
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showSafety) { SafetyView() }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        if case .success(let auth) = result,
           let credential = auth.credential as? ASAuthorizationAppleIDCredential {
            Task {
                try? await AuthService.shared.signInWithApple(credential: credential)
                showSafety = true
            }
        }
    }

    private func handleGoogleSignIn() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let vc = scene.windows.first?.rootViewController else { return }
        Task { try? await AuthService.shared.signInWithGoogle(presenting: vc) }
    }
}
