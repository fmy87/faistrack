import SwiftUI

struct TracksView: View {
    @StateObject private var viewModel = TracksViewModel()
    @State private var showCreateTrack = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    // The map always renders — previously it was only shown
                    // when tracks existed, so a user with zero published
                    // tracks would never see any map at all on this tab.
                    TracksOverviewMapView(tracks: viewModel.tracks)
                        .frame(height: 200)

                    if viewModel.tracks.isEmpty {
                        Spacer()
                        Image(systemName: "flag.checkered").font(.system(size: 64)).foregroundColor(.ftAccent)
                        Text(NSLocalizedString("tracks.empty", comment: ""))
                            .foregroundColor(.ftTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    } else {
                        List(viewModel.tracks) { track in
                            NavigationLink(destination: TrackDetailView(track: track)) {
                                TrackRowView(track: track)
                            }
                            .listRowBackground(Color.ftCard)
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("tab.tracks", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreateTrack = true } label: {
                        Image(systemName: "plus").foregroundColor(.ftAccent)
                    }
                }
            }
            .sheet(isPresented: $showCreateTrack) {
                CreateTrackView(onCreated: { Task { await viewModel.load() } })
            }
            .task {
                LocationService.shared.startUpdating()
                await viewModel.load()
            }
        }
    }
}

struct TrackRowView: View {
    let track: Track
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name).font(.system(size: 16, weight: .semibold))
                Text(track.distanceFormatted).font(.system(size: 13)).foregroundColor(.ftTextSecondary)
            }
            Spacer()
            if let bestTime = track.bestTime {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1fs", bestTime))
                        .font(.system(size: 18, weight: .bold)).foregroundColor(.ftAccent)
                    if let holder = track.bestTimeUsername {
                        Text(holder).font(.system(size: 11)).foregroundColor(.ftTextSecondary)
                    }
                }
            } else {
                Text(NSLocalizedString("tracks.noAttempts", comment: ""))
                    .font(.system(size: 12)).foregroundColor(.ftTextSecondary)
            }
        }.padding(.vertical, 4)
    }
}

class TracksViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    func load() async {
        tracks = (try? await FirebaseService.shared.getTracks()) ?? []
    }
}

