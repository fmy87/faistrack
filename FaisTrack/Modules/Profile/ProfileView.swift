import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.ftAccent)
                        Text(viewModel.user?.name ?? "")
                            .font(.system(size: 22, weight: .bold))
                        if let username = viewModel.user?.username, !username.isEmpty {
                            Text("@\(username)")
                                .foregroundColor(.ftTextSecondary)
                        }
                        HStack(spacing: 6) {
                            Text(viewModel.driverRank.icon)
                            Text(viewModel.driverRank.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.ftAccentOrange)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color.ftAccentOrange.opacity(0.15))
                        .cornerRadius(12)
                        if viewModel.driverRank != .legend {
                            ProgressView(value: viewModel.rankProgress)
                                .tint(.ftAccentOrange)
                                .frame(width: 140)
                        }
                    }

                    FTCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(NSLocalizedString("profile.username", comment: ""))
                                .font(.system(size: 14, weight: .medium)).foregroundColor(.ftTextSecondary)
                            HStack {
                                Text("@").foregroundColor(.ftTextSecondary)
                                TextField(NSLocalizedString("profile.username.placeholder", comment: ""), text: $viewModel.usernameInput)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .foregroundColor(.ftTextPrimary)
                                    .onChange(of: viewModel.usernameInput) { _ in
                                        viewModel.checkUsernameAvailability()
                                    }
                                if viewModel.isCheckingUsername {
                                    ProgressView()
                                }
                            }
                            .padding(12).background(Color.ftBackground).cornerRadius(10)

                            if let statusText = viewModel.usernameStatusText {
                                Text(statusText)
                                    .font(.system(size: 12))
                                    .foregroundColor(viewModel.usernameAvailable == true ? .speedGreen : .speedRed)
                            }

                            Button(action: { Task { await viewModel.saveUsername() } }) {
                                HStack {
                                    if viewModel.isSavingUsername { ProgressView().tint(.white) }
                                    Text(NSLocalizedString("general.save", comment: ""))
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background {
                                    // A ternary here fails to compile: Color.ftGradient
                                    // is actually a LinearGradient, not a Color, so the
                                    // two branches don't share a type. A ViewBuilder
                                    // closure lets each branch resolve independently.
                                    if viewModel.canSaveUsername {
                                        Color.ftGradient
                                    } else {
                                        Color.ftTextSecondary.opacity(0.3)
                                    }
                                }
                                .cornerRadius(12)
                            }
                            .disabled(!viewModel.canSaveUsername)
                        }
                    }

                    FTCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(NSLocalizedString("profile.instagram", comment: ""))
                                .font(.system(size: 14, weight: .medium)).foregroundColor(.ftTextSecondary)
                            HStack {
                                Text("@").foregroundColor(.ftTextSecondary)
                                TextField(NSLocalizedString("profile.instagramPlaceholder", comment: ""), text: $viewModel.instagramHandle)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .foregroundColor(.ftTextPrimary)
                            }
                            .padding(12).background(Color.ftBackground).cornerRadius(10)

                            Button(action: { Task { await viewModel.saveInstagram() } }) {
                                HStack {
                                    if viewModel.isSavingInstagram { ProgressView().tint(.white) }
                                    Text(NSLocalizedString("general.save", comment: ""))
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.ftGradient)
                                .cornerRadius(12)
                            }
                            .disabled(viewModel.isSavingInstagram)
                        }
                    }

                    FTCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: Binding(
                                get: { viewModel.isPrivateProfile },
                                set: { newValue in Task { await viewModel.setPrivateProfile(newValue) } }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("profile.privateProfile", comment: ""))
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(viewModel.isPrivateProfile
                                         ? NSLocalizedString("profile.privateProfile.desc", comment: "")
                                         : NSLocalizedString("profile.publicProfile.desc", comment: ""))
                                        .font(.system(size: 12))
                                        .foregroundColor(.ftTextSecondary)
                                }
                            }
                            .tint(.ftAccent)
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        // Previously this was set on failure but never
                        // actually displayed anywhere — a failed toggle
                        // save would silently revert with zero explanation,
                        // which looks identical to "the toggle is just
                        // broken" even when the real cause (e.g. a network
                        // blip) is knowable.
                        Text(errorMessage)
                            .font(.system(size: 12)).foregroundColor(.speedRed)
                            .multilineTextAlignment(.center)
                    }

                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Text(NSLocalizedString("profile.signOut", comment: ""))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.speedRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ftCard)
                            .cornerRadius(16)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            if isDeletingAccount { ProgressView().tint(.speedRed) }
                            Text(NSLocalizedString("profile.deleteAccount", comment: ""))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.speedRed.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .disabled(isDeletingAccount)

                    if let deleteError {
                        Text(deleteError).font(.system(size: 12)).foregroundColor(.speedRed)
                            .multilineTextAlignment(.center)
                    }
                }.padding(20)
            }
        }
        .navigationTitle(NSLocalizedString("tab.profile", comment: ""))
        .task { await viewModel.load() }
        .confirmationDialog(
            NSLocalizedString("profile.signOutConfirm", comment: ""),
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("profile.signOut", comment: ""), role: .destructive) {
                signOut()
            }
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) {}
        }
        .confirmationDialog(
            NSLocalizedString("profile.deleteAccountConfirm", comment: ""),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("profile.deleteAccount", comment: ""), role: .destructive) {
                Task { await deleteAccount() }
            }
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) {}
        }
    }

    private func signOut() {
        try? AuthService.shared.signOut()
        appState.currentScreen = .auth
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        deleteError = nil
        do {
            try await AuthService.shared.deleteAccount()
            appState.currentScreen = .auth
        } catch {
            // Firebase requires a recent sign-in to delete the Auth account.
            // Note the data is already gone at this point (deleteAllUserData
            // runs first) even if this step fails — surfacing that clearly
            // rather than implying nothing happened.
            deleteError = error.localizedDescription
        }
        isDeletingAccount = false
    }
}

struct ProfileRow: View {
    let icon: String
    let title: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.ftAccent).frame(width: 28)
            Text(title).foregroundColor(.ftTextPrimary)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.ftTextSecondary).font(.system(size: 13))
        }
        .padding(16)
        .background(Color.ftCard)
        .cornerRadius(14)
    }
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: FTUser?
    @Published var instagramHandle: String = ""
    @Published var isSavingInstagram = false
    @Published var isPrivateProfile: Bool = false
    @Published var errorMessage: String?
    @Published var driverXP: Double = 0

    var driverRank: DriverRank { DriverRank.forXP(driverXP) }
    var rankProgress: Double { DriverRank.progress(for: driverXP) }

    @Published var usernameInput: String = ""
    @Published var usernameAvailable: Bool?
    @Published var isCheckingUsername = false
    @Published var isSavingUsername = false
    private var usernameCheckTask: Task<Void, Never>?

    /// nil means "no status to show yet" (unchanged from current, empty, or
    /// invalid format before any check runs) — the view only shows a status
    /// line once there's something meaningful to say.
    var usernameStatusText: String? {
        if isCheckingUsername { return nil }
        guard let usernameAvailable else { return nil }
        return usernameAvailable
            ? NSLocalizedString("profile.username.available", comment: "")
            : NSLocalizedString("profile.username.taken", comment: "")
    }

    var canSaveUsername: Bool {
        !isSavingUsername && usernameAvailable == true &&
        usernameInput.lowercased() != (user?.username.lowercased() ?? "")
    }

    func load() async {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        do {
            if let existing = try await FirebaseService.shared.getUser(uid: uid) {
                user = existing
            } else {
                // Safety net for accounts that signed in before profile
                // creation existed at all (or if it failed at sign-in time).
                let fallbackName = AuthService.shared.currentUser?.displayName ?? ""
                user = try await FirebaseService.shared.ensureUserProfile(
                    uid: uid, name: fallbackName, email: AuthService.shared.currentUser?.email
                )
            }
            isPrivateProfile = user?.isPrivateProfile ?? false
            usernameInput = user?.username ?? ""
            instagramHandle = user?.instagramHandle ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
        await loadDriverRank(uid: uid)
    }

    /// Reuses the same all-time aggregate document the Rival card reads
    /// (distance + drive count already sit there, maintained by
    /// LeaderboardService) rather than re-fetching and re-summing every
    /// raw Drive just to compute XP.
    private func loadDriverRank(uid: String) async {
        async let totals = FirebaseService.shared.getAllTimeTotals(uid: uid)
        async let tracksCreated = FirebaseService.shared.getTrackCount(ownerUID: uid)
        let myTotals = (try? await totals) ?? RivalTotals(distanceKm: 0, drives: 0, hours: 0, topSpeedKmh: 0, longestKm: 0)
        let myTracksCreated = (try? await tracksCreated) ?? 0
        driverXP = DriverRank.computeXP(
            totalDistanceKm: myTotals.distanceKm,
            totalDrives: myTotals.drives,
            tracksCreated: myTracksCreated
        )
    }

    /// Debounced, same pattern as friend search — waits for typing to
    /// pause before hitting Firestore, and a fresh keystroke cancels any
    /// still-in-flight previous check.
    func checkUsernameAvailability() {
        usernameCheckTask?.cancel()
        let candidate = usernameInput.lowercased().trimmingCharacters(in: .whitespaces)
        let currentUsername = user?.username.lowercased() ?? ""

        guard candidate != currentUsername, isValidUsernameFormat(candidate) else {
            usernameAvailable = candidate.isEmpty || candidate == currentUsername ? nil : false
            return
        }

        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, candidate == self.usernameInput.lowercased() else { return }
            isCheckingUsername = true
            let uid = AuthService.shared.currentUser?.uid
            let available = (try? await FirebaseService.shared.isUsernameAvailable(candidate, excludingUid: uid)) ?? false
            guard !Task.isCancelled else { return }
            usernameAvailable = available
            isCheckingUsername = false
        }
    }

    /// Lowercase letters, numbers, and underscores only, 3-20 characters —
    /// matches how generateUsername already sanitizes auto-created ones, so
    /// a manually chosen username can't end up in some format the rest of
    /// the app (search, leaderboard display) doesn't expect.
    private func isValidUsernameFormat(_ candidate: String) -> Bool {
        candidate.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }

    func saveUsername() async {
        guard let uid = AuthService.shared.currentUser?.uid, canSaveUsername else { return }
        let candidate = usernameInput.lowercased().trimmingCharacters(in: .whitespaces)
        isSavingUsername = true
        errorMessage = nil
        do {
            try await FirebaseService.shared.updateUsername(uid: uid, newUsername: candidate)
            user?.username = candidate
            usernameInput = candidate
            usernameAvailable = nil
            ToastManager.shared.showSuccess(NSLocalizedString("toast.usernameSaved", comment: ""))
        } catch {
            errorMessage = error.localizedDescription
            ToastManager.shared.showError(error.localizedDescription)
        }
        isSavingUsername = false
    }

    /// Same race-condition guard as saveUsername/setPrivateProfile: .task {
    /// load() } runs asynchronously, so a person who types and taps Save
    /// before it resolves would otherwise hit a false "no profile" error
    /// even though the profile does exist (or is about to).
    func saveInstagram() async {
        isSavingInstagram = true
        errorMessage = nil
        if user == nil {
            await load()
        }
        guard var user = user else {
            errorMessage = NSLocalizedString("profile.noProfile", comment: "")
            isSavingInstagram = false
            return
        }
        // Stored without a leading "@" — the "@" is UI chrome shown next to
        // the field, not part of the value, so strip one off if someone
        // pastes a handle that includes it.
        let handle = instagramHandle.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        user.instagramHandle = handle.isEmpty ? nil : handle
        do {
            try await FirebaseService.shared.saveUser(user)
            self.user = user
            instagramHandle = handle
            ToastManager.shared.showSuccess(NSLocalizedString("profile.saved", comment: ""))
        } catch {
            errorMessage = error.localizedDescription
            ToastManager.shared.showError(error.localizedDescription)
        }
        isSavingInstagram = false
    }

    func setPrivateProfile(_ value: Bool) async {
        // Same race condition previously fixed for Instagram saving: this
        // view's .task { load() } runs asynchronously, so if the person
        // taps the toggle before that finishes, `user` is still nil here —
        // the toggle would silently fail to move at all rather than just
        // being slow. Try loading once before giving up.
        if user == nil {
            await load()
        }
        guard var user = user else { errorMessage = NSLocalizedString("profile.noProfile", comment: ""); return }
        let previous = isPrivateProfile
        isPrivateProfile = value // optimistic update for a responsive toggle
        errorMessage = nil
        user.isPrivateProfile = value
        do {
            try await FirebaseService.shared.saveUser(user)
            self.user = user
        } catch {
            isPrivateProfile = previous // revert on failure
            errorMessage = error.localizedDescription
        }
    }
}






