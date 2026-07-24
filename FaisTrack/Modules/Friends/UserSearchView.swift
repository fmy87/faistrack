import SwiftUI

struct UserSearchView: View {
    @StateObject private var viewModel = UserSearchViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    TextField(NSLocalizedString("friends.search.placeholder", comment: ""), text: $viewModel.query)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(14).background(Color.ftCard).cornerRadius(12).padding()
                        .onChange(of: viewModel.query) { _ in
                            Task { await viewModel.search() }
                        }

                    if viewModel.isSearching {
                        ProgressView().padding(.top, 32)
                        Spacer()
                    } else if !viewModel.query.isEmpty && viewModel.results.isEmpty {
                        Spacer()
                        Text(NSLocalizedString("friends.search.noResults", comment: ""))
                            .foregroundColor(.ftTextSecondary)
                        Spacer()
                    } else {
                        List(viewModel.results) { user in
                            UserSearchRow(user: user, status: viewModel.status(for: user.uid)) {
                                Task { await viewModel.sendRequest(to: user) }
                            }
                            .listRowBackground(Color.ftCard)
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("friends.search.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("general.cancel", comment: "")) { dismiss() }
                }
            }
        }
    }
}

private struct UserSearchRow: View {
    let user: PublicProfile
    let status: FriendshipStatus
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Circle().fill(Color.ftAccent.opacity(0.25)).frame(width: 36, height: 36)
                .overlay(Text(String(user.username.prefix(1)).uppercased()).font(.system(size: 14, weight: .bold)))
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.system(size: 15, weight: .semibold))
                Text("@\(user.username)").font(.system(size: 12)).foregroundColor(.ftTextSecondary)
            }
            Spacer()
            actionButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .none:
            Button(action: onAdd) {
                Text(NSLocalizedString("friends.add", comment: ""))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.ftAccent).cornerRadius(14)
            }
        case .requestSent:
            Text(NSLocalizedString("friends.requestSent", comment: ""))
                .font(.system(size: 12)).foregroundColor(.ftTextSecondary)
        case .requestReceived:
            Text(NSLocalizedString("friends.requestReceived", comment: ""))
                .font(.system(size: 12)).foregroundColor(.ftAccentOrange)
        case .friends:
            Text(NSLocalizedString("friends.alreadyFriends", comment: ""))
                .font(.system(size: 12)).foregroundColor(.speedGreen)
        }
    }
}

@MainActor
class UserSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [PublicProfile] = []
    @Published var isSearching = false
    @Published private var statuses: [String: FriendshipStatus] = [:]

    private var searchTask: Task<Void, Never>?

    func status(for uid: String) -> FriendshipStatus { statuses[uid] ?? .none }

    /// Debounced so every keystroke doesn't fire its own Firestore query —
    /// waits briefly for typing to pause, and a new search cancels any
    /// still-in-flight previous one.
    func search() async {
        searchTask?.cancel()
        let currentQuery = query
        guard !currentQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, currentQuery == self.query else { return }
            await self.performSearch(currentQuery)
        }
    }

    private func performSearch(_ text: String) async {
        guard let myUid = AuthService.shared.currentUser?.uid else { return }
        isSearching = true
        let found = (try? await FirebaseService.shared.searchUsers(query: text, excludingUid: myUid)) ?? []
        guard !Task.isCancelled else { return }
        results = found
        isSearching = false
        for user in found {
            if let status = try? await FirebaseService.shared.friendshipStatus(myUid: myUid, otherUid: user.uid) {
                statuses[user.uid] = status
            }
        }
    }

    func sendRequest(to user: PublicProfile) async {
        guard let myUid = AuthService.shared.currentUser?.uid,
              let me = try? await FirebaseService.shared.getUser(uid: myUid) else { return }
        do {
            try await FirebaseService.shared.sendFriendRequest(from: me, toUid: user.uid)
            statuses[user.uid] = .requestSent
        } catch {
            // Leave status unchanged so the Add button still shows and the
            // person can retry — but they need to actually see why it
            // failed, not just have the tap silently do nothing.
            ToastManager.shared.showError(error.localizedDescription)
        }
    }
}
