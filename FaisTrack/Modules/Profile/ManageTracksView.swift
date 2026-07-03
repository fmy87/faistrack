import SwiftUI

/// Lets the user review and delete tracks they've published.
struct ManageTracksView: View {
    @State private var tracks: [Track] = []
    @State private var isLoading = true

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
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(NSLocalizedString("profile.manageTracks", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .task { await load() }
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
                try? await FirebaseService.shared.deleteTrack(trackId: id)
            }
        }
    }
}
