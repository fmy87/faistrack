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
                                    FriendRow(
                                        friend: friend,
                                        isDriving: viewModel.liveStatuses[friend.uid] == true,
                                        isRival: viewModel.rivalUID == friend.uid,
                                        onToggleRival: { Task { await viewModel.toggleRival(friend) } }
                                    )
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
            .task {
                await viewModel.load()
                await viewModel.startLivePolling()
            }
            .onDisappear { viewModel.stopLivePolling() }
        }
        .sheet(isPresented: $showSearch, onDismiss: { Task { await viewModel.load() } }) {
            UserSearchView()
        }
    }
}

private struct FriendRow: View {
    let friend: Friend
    let isDriving: Bool
    var isRival: Bool = false
    var onToggleRival: (() -> Void)? = nil
    var body: some View {
        HStack {
            ZStack(alignment: .bottomTrailing) {
                Circle().fill(Color.ftAccent.opacity(0.25)).frame(width: 36, height: 36)
                    .overlay(Text(String(friend.username.prefix(1)).uppercased()).font(.system(size: 14, weight: .bold)))
                if isDriving {
                    Circle().fill(Color.speedGreen)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.ftCard, lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.username).font(.system(size: 15, weight: .semibold))
                if isDriving {
                    Label(NSLocalizedString("friends.drivingNow", comment: ""), systemImage: "car.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.speedGreen)
                }
            }
            Spacer()
            // Tapping sets this friend as Rival, or clears it if they
            // already are one — only one rival at a time, so setting a new
            // one implicitly replaces whichever friend held it before.
            Button(action: { onToggleRival?() }) {
                Image(systemName: isRival ? "flag.2.crossed.fill" : "flag.2.crossed")
                    .font(.system(size: 16))
                    .foregroundColor(isRival ? .ftAccentOrange : .ftTextSecondary.opacity(0.5))
            }
            .buttonStyle(.plain)
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
    @Published var liveStatuses: [String: Bool] = [:]
    @Published var isLoading = true
    @Published var rivalUID: String?

    private var pollTask: Task<Void, Never>?

    func load() async {
        guard let uid = AuthService.shared.currentUser?.uid else { isLoading = false; return }
        async let f = FirebaseService.shared.getFriends(uid: uid)
        async let r = FirebaseService.shared.getFriendRequests(uid: uid)
        async let me = FirebaseService.shared.getUser(uid: uid)
        friends = (try? await f) ?? []
        requests = (try? await r) ?? []
        rivalUID = (try? await me)?.rivalUID
        isLoading = false
    }

    /// Sets this friend as Rival, or clears the rival if they already were
    /// one. Optimistic update with rollback, same pattern as accept/decline
    /// above — the UI reflects the change immediately rather than waiting
    /// on the network round trip.
    func toggleRival(_ friend: Friend) async {
        guard let uid = AuthService.shared.currentUser?.uid else { return }
        let previous = rivalUID
        let newRival = (rivalUID == friend.uid) ? nil : friend.uid
        rivalUID = newRival
        do {
            try await FirebaseService.shared.setRival(uid: uid, rivalUID: newRival)
        } catch {
            rivalUID = previous
        }
    }

    /// There's no persistent Firestore listener infrastructure elsewhere in
    /// this app (everything else is one-shot fetch), so this keeps that
    /// same pattern rather than introducing a new architecture just for
    /// this feature — polls every 20s while the Friends tab is visible,
    /// stops the moment it isn't (see FriendsView.onDisappear).
    func startLivePolling() async {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await refreshLiveStatuses()
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
    }

    func stopLivePolling() {
        pollTask?.cancel()
    }

    func refreshLiveStatuses() async {
        let uids = friends.map(\.uid)
        guard !uids.isEmpty else { return }
        liveStatuses = (try? await FirebaseService.shared.getFriendsLiveStatus(friendUIDs: uids)) ?? [:]
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


