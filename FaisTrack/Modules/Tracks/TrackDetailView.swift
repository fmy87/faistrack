import SwiftUI
import CoreLocation

struct TrackDetailView: View {
    let track: Track
    @State private var results: [TrackResult] = []

    private var routeCoordinates: [CLLocationCoordinate2D] {
        PolylineCodec.decode(track.polylineEncoded)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if routeCoordinates.count > 1 {
                    RouteMapView(coordinates: routeCoordinates)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                FTCard {
                    HStack {
                        FTStatBadge(value: track.distanceFormatted, label: NSLocalizedString("tracks.distance", comment: ""))
                        Divider()
                        FTStatBadge(value: track.bestTime.map { String(format: "%.1fs", $0) } ?? "—",
                                    label: NSLocalizedString("tracks.bestTime", comment: ""))
                        Divider()
                        FTStatBadge(value: "\(track.attemptCount)", label: NSLocalizedString("tracks.attempts", comment: ""))
                    }
                }

                NavigationLink(destination: CompeteView(track: track)) {
                    Text(NSLocalizedString("tracks.compete", comment: ""))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.ftGradient)
                        .cornerRadius(16)
                }

                if !results.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(NSLocalizedString("tracks.leaderboard", comment: ""))
                            .font(.system(size: 16, weight: .bold))
                        ForEach(Array(results.enumerated()), id: \.1.id) { index, result in
                            HStack {
                                Text("#\(index + 1)").font(.system(size: 14, weight: .bold))
                                    .foregroundColor(index == 0 ? .ftAccent : .ftTextSecondary)
                                    .frame(width: 32)
                                Text(result.username).font(.system(size: 14))
                                Spacer()
                                Text(result.durationFormatted).font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.ftCard)
                    .cornerRadius(16)
                }
            }.padding(16)
        }
        .background(Color.ftBackground.ignoresSafeArea())
        .navigationTitle(track.name)
        .task { await loadLeaderboard() }
    }

    private func loadLeaderboard() async {
        guard let id = track.id else { return }
        results = (try? await FirebaseService.shared.getTrackLeaderboard(trackId: id)) ?? []
    }
}
