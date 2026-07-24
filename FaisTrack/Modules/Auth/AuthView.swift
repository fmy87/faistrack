import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = false
    @State private var showChooseUsername = false
    @State private var showSafety = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            // Real footage instead of the old SF Symbol car silhouette —
            // muted and looping so it reads as ambient atmosphere behind
            // the screen, not something demanding attention on its own.
            SignupCarLoopView()
                .ignoresSafeArea()

            // Scrims top and bottom so the title and sign-in buttons stay
            // legible over live footage instead of whatever's happening in
            // the frame at that moment — same reasoning as the intro
            // video's top scrim.
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.ftBackground.opacity(0.85), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 220)
                Spacer()
                LinearGradient(colors: [.clear, Color.ftBackground.opacity(0.92)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 260)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

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
        .sheet(isPresented: $showChooseUsername, onDismiss: { showSafety = true }) {
            ChooseUsernameView()
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
                        showChooseUsername = true
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
                    showChooseUsername = true
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


