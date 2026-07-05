import SwiftUI

/// Lets the user review tracks they've published. Deleting a published
/// track is intentionally restricted to the admin account (see
/// AdminConfig) — once a track is out in the world and other people may
/// have raced it, its creator shouldn't be able to erase it and their
/// results out from under them. The matching Firestore rule enforces this
/// server-side too, not just here in the UI.
struct ManageTracksView: View {
    @State private var tracks: [Track] = []
    @State private var isLoading = true
    @State private var deleteError: String?

    private var canDelete: Bool { AdminConfig.isCurrentUserAdmin }

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            if !isLoading && tracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "flag.checkered").font(.system(size: 48)).foregroundColor(.ftAccent)
                    Text(NSLocalizedString("tracks.empty", comment: ""))
                        .foregroundColor(.ftTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                List {
                    ForEach(tracks) { track in
                        TrackRowView(track: track)
                            .listRowBackground(Color.ftCard)
                    }
                    .onDelete(perform: canDelete ? delete : nil)
                }
                .listStyle(.insetGrouped)

                if !canDelete && !tracks.isEmpty {
                    Text(NSLocalizedString("tracks.deleteRestricted", comment: ""))
                        .font(.system(size: 12)).foregroundColor(.ftTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
        .navigationTitle(NSLocalizedString("profile.manageTracks", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canDelete {
                EditButton()
            }
        }
        .task { await load() }
        .alert(NSLocalizedString("general.error", comment: ""), isPresented: Binding(
            get: { deleteError != nil }, set: { if !$0 { deleteError = nil } }
        )) {
            Button(NSLocalizedString("general.ok", comment: ""), role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func load() async {
        guard let uid = AuthService.shared.currentUser?.uid else { isLoading = false; return }
        let all = (try? await FirebaseService.shared.getTracks(limit: 200)) ?? []
        tracks = all.filter { $0.ownerUID == uid }
        isLoading = false
    }

    private func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { tracks[$0] }
        tracks.remove(atOffsets: offsets)
        Task {
            for track in toDelete {
                guard let id = track.id else { continue }
                do {
                    try await FirebaseService.shared.deleteTrack(trackId: id)
                } catch {
                    // Put it back rather than leaving it silently vanished
                    // from the list while it still exists on the server.
                    tracks.append(track)
                    deleteError = error.localizedDescription
                }
            }
        }
    }
}
