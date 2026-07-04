import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?

    var body: some View {
        NavigationView {
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
    @Published var isPrivateProfile: Bool = false
    @Published var errorMessage: String?

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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setPrivateProfile(_ value: Bool) async {
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
