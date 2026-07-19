import SwiftUI
import CoreLocation

struct TracksView: View {
    @StateObject private var viewModel = TracksViewModel()
    @State private var showCreateTrack = false
    @State private var selectedTrackFromMap: Track?
    @State private var searchText = ""
    @State private var sortOption: TrackSortOption = .newest

    /// Applies the search text and sort option on top of whatever tracks
    /// have loaded — computed fresh each render rather than stored, since
    /// there's no expensive work here and it keeps the two controls always
    /// in sync with the underlying data with no extra state to manage.
    private var displayedTracks: [Track] {
        var result = viewModel.tracks
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.name.lowercased().contains(query) || $0.ownerUsername.lowercased().contains(query)
            }
        }
        switch sortOption {
        case .newest:
            result.sort { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
        case .shortest:
            result.sort { $0.distance < $1.distance }
        case .longest:
            result.sort { $0.distance > $1.distance }
        case .bestTime:
            // Tracks with no attempts yet sink to the bottom rather than
            // sorting as if their best time were 0 seconds.
            result.sort { a, b in
                switch (a.bestTime, b.bestTime) {
                case let (x?, y?): return x < y
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return false
                }
            }
        case .nearest:
            guard let userLocation = LocationService.shared.currentLocation else { break }
            result.sort { a, b in
                let da = CLLocation(latitude: a.startLatitude, longitude: a.startLongitude).distance(from: userLocation)
                let db = CLLocation(latitude: b.startLatitude, longitude: b.startLongitude).distance(from: userLocation)
                return da < db
            }
        }
        return result
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    // The map always renders — previously it was only shown
                    // when tracks existed, so a user with zero published
                    // tracks would never see any map at all on this tab.
                    // Tapping a track's marker on the map selects it
                    // directly, without needing to find it in the list below.
                    TracksOverviewMapView(tracks: viewModel.tracks, onSelectTrack: { track in
                        selectedTrackFromMap = track
                    })
                    .frame(height: 200)

                    // Hidden NavigationLink driven by map taps — iOS 15
                    // doesn't have navigationDestination(item:), so this is
                    // the standard programmatic-push pattern for that target.
                    NavigationLink(
                        destination: selectedTrackFromMap.map { TrackDetailView(track: $0) },
                        isActive: Binding(
                            get: { selectedTrackFromMap != nil },
                            set: { isActive in if !isActive { selectedTrackFromMap = nil } }
                        )
                    ) { EmptyView() }
                    .hidden()

                    sortBar

                    if viewModel.tracks.isEmpty {
                        Spacer()
                        Image(systemName: "flag.checkered").font(.system(size: 64)).foregroundColor(.ftAccent)
                        Text(NSLocalizedString("tracks.empty", comment: ""))
                            .foregroundColor(.ftTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    } else if displayedTracks.isEmpty {
                        Spacer()
                        Text(NSLocalizedString("tracks.noSearchResults", comment: ""))
                            .foregroundColor(.ftTextSecondary)
                            .padding()
                        Spacer()
                    } else {
                        List(displayedTracks) { track in
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
            .searchable(text: $searchText, prompt: NSLocalizedString("tracks.searchPrompt", comment: ""))
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

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TrackSortOption.allCases, id: \.self) { option in
                    Button(option.label) { sortOption = option }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(sortOption == option ? Color.ftAccent : Color.ftCard)
                        .foregroundColor(sortOption == option ? .white : .ftTextPrimary)
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal).padding(.vertical, 8)
        }
    }
}

enum TrackSortOption: String, CaseIterable {
    case newest, shortest, longest, bestTime, nearest

    var label: String {
        switch self {
        case .newest: return NSLocalizedString("tracks.sort.newest", comment: "")
        case .shortest: return NSLocalizedString("tracks.sort.shortest", comment: "")
        case .longest: return NSLocalizedString("tracks.sort.longest", comment: "")
        case .bestTime: return NSLocalizedString("tracks.sort.bestTime", comment: "")
        case .nearest: return NSLocalizedString("tracks.sort.nearest", comment: "")
        }
    }
}

struct TrackRowView: View {
    let track: Track
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name).font(.system(size: 16, weight: .semibold))
                HStack(spacing: 6) {
                    Text(track.distanceFormatted)
                    Text("·")
                    // Shows who published this track — since the Tracks tab
                    // lists every user's tracks (not just your own), this
                    // makes it obvious you can browse and compete on tracks
                    // other people created, not only ones you made yourself.
                    Text("@\(track.ownerUsername)")
                }
                .font(.system(size: 13)).foregroundColor(.ftTextSecondary)
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
