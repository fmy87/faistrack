import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSignOutConfirm = false

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
                                        if viewModel.isSaving { ProgressView().tint(.white) }
                                        Text(NSLocalizedString("general.save", comment: ""))
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.ftGradient)
                                    .cornerRadius(12)
                                }
                                .disabled(viewModel.isSaving)

                                if viewModel.saveConfirmed {
                                    Text(NSLocalizedString("profile.saved", comment: ""))
                                        .font(.system(size: 12)).foregroundColor(.speedGreen)
                                }
                            }
                        }

                        VStack(spacing: 12) {
                            NavigationLink(destination: ManageDrivesView()) {
                                ProfileRow(icon: "car.fill", title: NSLocalizedString("profile.manageDrives", comment: ""))
                            }
                            NavigationLink(destination: ManageTracksView()) {
                                ProfileRow(icon: "flag.checkered", title: NSLocalizedString("profile.manageTracks", comment: ""))
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
        }
    }

    private func signOut() {
        try? AuthService.shared.signOut()
        appState.currentScreen = .auth
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
    @Published var isSaving = false
    @Published var saveConfirmed = false

    func load() async {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        user = try? await FirebaseService.shared.getUser(uid: uid)
        instagramHandle = user?.instagramHandle ?? ""
    }

    func saveInstagram() async {
        guard var user = user else { return }
        isSaving = true
        saveConfirmed = false
        user.instagramHandle = instagramHandle
        try? await FirebaseService.shared.saveUser(user)
        self.user = user
        isSaving = false
        saveConfirmed = true
    }
}
