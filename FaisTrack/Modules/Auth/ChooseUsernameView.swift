import SwiftUI

/// Shown once, right after signing in for the first time, letting the
/// person pick their own username instead of silently keeping whatever
/// auto-generated one ensureUserProfile() assigned at sign-in (see
/// AuthService.signInWithApple/signInWithGoogle). Reuses the same
/// debounced live-availability-check UX as editing a username later in
/// Profile, so both places behave identically.
struct ChooseUsernameView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ChooseUsernameViewModel()

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 56)).foregroundColor(.ftAccent)
                Text(NSLocalizedString("onboarding.chooseUsername.title", comment: ""))
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(NSLocalizedString("onboarding.chooseUsername.subtitle", comment: ""))
                    .font(.system(size: 14)).foregroundColor(.ftTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                FTCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("@").foregroundColor(.ftTextSecondary)
                            TextField(NSLocalizedString("profile.username.placeholder", comment: ""), text: $viewModel.usernameInput)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.ftTextPrimary)
                                .onChange(of: viewModel.usernameInput) { _ in
                                    viewModel.checkUsernameAvailability()
                                }
                            if viewModel.isChecking { ProgressView() }
                        }
                        .padding(12).background(Color.ftBackground).cornerRadius(10)

                        if let statusText = viewModel.statusText {
                            Text(statusText)
                                .font(.system(size: 12))
                                .foregroundColor(viewModel.isAvailable == true ? .speedGreen : .speedRed)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
                Spacer()

                FTPrimaryButton(
                    title: NSLocalizedString("onboarding.chooseUsername.continue", comment: ""),
                    isLoading: viewModel.isSaving
                ) {
                    Task {
                        await viewModel.confirm()
                        dismiss()
                    }
                }
                .disabled(!viewModel.canContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .interactiveDismissDisabled() // this step shouldn't be swipe-skippable
        .task { await viewModel.load() }
    }
}

@MainActor
class ChooseUsernameViewModel: ObservableObject {
    @Published var usernameInput = ""
    @Published var isAvailable: Bool?
    @Published var isChecking = false
    @Published var isSaving = false
    private var originalUsername = ""
    private var checkTask: Task<Void, Never>?

    var statusText: String? {
        if isChecking { return nil }
        guard let isAvailable else { return nil }
        return isAvailable
            ? NSLocalizedString("profile.username.available", comment: "")
            : NSLocalizedString("profile.username.taken", comment: "")
    }

    /// Lets the person continue either with the auto-generated default
    /// unchanged (already valid, already saved by ensureUserProfile at
    /// sign-in) or with a new username they've confirmed is available —
    /// never with something unconfirmed.
    var canContinue: Bool {
        !isSaving && (usernameInput.lowercased() == originalUsername.lowercased() || isAvailable == true)
    }

    func load() async {
        guard let uid = AuthService.shared.currentUser?.uid,
              let user = try? await FirebaseService.shared.getUser(uid: uid) else { return }
        originalUsername = user.username
        usernameInput = user.username
    }

    /// Same debounce pattern as ProfileViewModel's username editing — waits
    /// for typing to pause before hitting Firestore.
    func checkUsernameAvailability() {
        checkTask?.cancel()
        let candidate = usernameInput.lowercased().trimmingCharacters(in: .whitespaces)
        guard candidate != originalUsername.lowercased(), isValidFormat(candidate) else {
            isAvailable = candidate.isEmpty || candidate == originalUsername.lowercased() ? nil : false
            return
        }
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, candidate == self.usernameInput.lowercased() else { return }
            isChecking = true
            let uid = AuthService.shared.currentUser?.uid
            let available = (try? await FirebaseService.shared.isUsernameAvailable(candidate, excludingUid: uid)) ?? false
            guard !Task.isCancelled else { return }
            isAvailable = available
            isChecking = false
        }
    }

    private func isValidFormat(_ candidate: String) -> Bool {
        candidate.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }

    func confirm() async {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        let candidate = usernameInput.lowercased().trimmingCharacters(in: .whitespaces)
        guard candidate != originalUsername.lowercased() else { return } // nothing changed, nothing to save
        isSaving = true
        try? await FirebaseService.shared.updateUsername(uid: uid, newUsername: candidate)
        isSaving = false
    }
}
