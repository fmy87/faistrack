import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showSearch = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.friends.isEmpty && viewModel.requests.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.fill").font(.system(size: 64)).foregroundColor(.ftAccent)
                        Text(NSLocalizedString("friends.empty.title", comment: ""))
                            .font(.system(size: 22, weight: .bold))
                        Text(NSLocalizedString("friends.empty.subtitle", comment: ""))
                            .foregroundColor(.ftTextSecondary).multilineTextAlignment(.center)
                        FTPrimaryButton(title: NSLocalizedString("friends.add", comment: "")) { showSearch = true }
                            .padding(.horizontal, 40)
                    }.padding(32)
                } else {
                    List {
                        if !viewModel.requests.isEmpty {
                            Section(NSLocalizedString("friends.requests", comment: "")) {
                                ForEach(viewModel.requests) { request in
                                    FriendRequestRow(
                                        request: request,
                                        onAccept: { Task { await viewModel.accept(request) } },
                                        onDecline: { Task { await viewModel.decline(request) } }
                                    )
                                    .listRowBackground(Color.ftCard)
                                }
                            }
                        }
                        if !viewModel.friends.isEmpty {
                            Section(NSLocalizedString("friends.myFriends", comment: "")) {
                                ForEach(viewModel.friends) { friend in
                                    FriendRow(friend: friend)
                                        .listRowBackground(Color.ftCard)
                                }
                                .onDelete { offsets in
                                    Task { await viewModel.removeFriends(at: offsets) }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(NSLocalizedString("tab.friends", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSearch = true } label: {
                        Image(systemName: "person.badge.plus").foregroundColor(.ftAccent)
                    }
                }
            }
            .task { await viewModel.load() }
        }
        .sheet(isPresented: $showSearch, onDismiss: { Task { await viewModel.load() } }) {
            UserSearchView()
        }
    }
}

private struct FriendRow: View {
    let friend: Friend
    var body: some View {
        HStack {
            Circle().fill(Color.ftAccent.opacity(0.25)).frame(width: 36, height: 36)
                .overlay(Text(String(friend.username.prefix(1)).uppercased()).font(.system(size: 14, weight: .bold)))
            Text(friend.username).font(.system(size: 15, weight: .semibold))
            Spacer()
        }.padding(.vertical, 4)
    }
}

private struct FriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    var body: some View {
        HStack {
            Circle().fill(Color.ftAccentOrange.opacity(0.25)).frame(width: 36, height: 36)
                .overlay(Text(String(request.fromUsername.prefix(1)).uppercased()).font(.system(size: 14, weight: .bold)))
            Text(request.fromUsername).font(.system(size: 15, weight: .semibold))
            Spacer()
            Button(action: onAccept) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.speedGreen).font(.system(size: 22))
            }
            Button(action: onDecline) {
                Image(systemName: "xmark.circle.fill").foregroundColor(.speedRed).font(.system(size: 22))
            }
        }.padding(.vertical, 4)
    }
}

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var requests: [FriendRequest] = []
    @Published var isLoading = true

    func load() async {
        guard let uid = AuthService.shared.currentUser?.uid else { isLoading = false; return }
        async let f = FirebaseService.shared.getFriends(uid: uid)
        async let r = FirebaseService.shared.getFriendRequests(uid: uid)
        friends = (try? await f) ?? []
        requests = (try? await r) ?? []
        isLoading = false
    }

    func accept(_ request: FriendRequest) async {
        guard let uid = AuthService.shared.currentUser?.uid,
              let me = try? await FirebaseService.shared.getUser(uid: uid) else { return }
        // Optimistically remove from the pending list so a double-tap can't
        // fire the accept twice while the network call is in flight.
        requests.removeAll { $0.id == request.id }
        do {
            try await FirebaseService.shared.acceptFriendRequest(uid: uid, myUsername: me.username, myPhotoURL: me.photoURL, request: request)
            await load()
        } catch {
            requests.append(request) // put it back if the accept failed
        }
    }

    func decline(_ request: FriendRequest) async {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        requests.removeAll { $0.id == request.id }
        try? await FirebaseService.shared.declineFriendRequest(uid: uid, fromUid: request.fromUid)
    }

    func removeFriends(at offsets: IndexSet) async {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        let toRemove = offsets.map { friends[$0] }
        friends.remove(atOffsets: offsets)
        for friend in toRemove {
            try? await FirebaseService.shared.removeFriend(uid: uid, friendUid: friend.uid)
        }
    }
}
