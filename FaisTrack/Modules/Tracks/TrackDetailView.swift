import SwiftUI
import CoreLocation

struct TrackDetailView: View {
    let track: Track
    @State private var results: [TrackResult] = []
    @State private var showShareCard = false

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

                // Makes it explicit this track (and every other one in the
                // Tracks list) can belong to anyone, not just you — the list
                // shows every user's published tracks and this one is
                // fully competable regardless of who created it.
                Text(String(format: NSLocalizedString("tracks.createdBy", comment: ""), track.ownerUsername))
                    .font(.system(size: 13)).foregroundColor(.ftTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                recordHolderCard

                FTCard {
                    HStack {
                        FTStatBadge(value: track.distanceFormatted, label: NSLocalizedString("tracks.distance", comment: ""))
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

                FTSecondaryButton(title: NSLocalizedString("tracks.shareCard", comment: "")) {
                    showShareCard = true
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
        .sheet(isPresented: $showShareCard) {
            TrackShareCardView(track: track)
        }
    }

    /// A distinct, trophy-styled card for whoever currently holds this
    /// track's best time — previously the best time was just another
    /// number in a plain stat row, easy to miss as "the thing everyone's
    /// actually competing for." Reuses bestTimeTopSpeed/bestTimeCarName
    /// (already captured whenever a new record is set) so this can show
    /// the record holder's speed and car with no extra lookup.
    private var recordHolderCard: some View {
        Group {
            if let bestTime = track.bestTime, let holder = track.bestTimeUsername {
                ZStack {
                    LinearGradient(colors: [.black, Color(hex: "#1A0000")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill").foregroundColor(.yellow)
                            Text(NSLocalizedString("tracks.recordHolder", comment: ""))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                        Text("@\(holder)")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.white)
                        Text(String(format: "%.2fs", bestTime))
                            .font(.system(size: 44, weight: .black))
                            .foregroundColor(.ftAccent)
                        HStack(spacing: 16) {
                            if let topSpeed = track.bestTimeTopSpeed, topSpeed > 0 {
                                Label(String(format: "%.0f km/h", topSpeed), systemImage: "gauge.with.dots.needle.67percent")
                            }
                            if let carName = track.bestTimeCarName {
                                Label(carName, systemImage: "car.fill")
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(20)
                }
                .cornerRadius(20)
            } else {
                FTCard {
                    VStack(spacing: 8) {
                        Image(systemName: "flag.checkered").font(.system(size: 28)).foregroundColor(.ftTextSecondary)
                        Text(NSLocalizedString("tracks.noRecordYet", comment: ""))
                            .font(.system(size: 14)).foregroundColor(.ftTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func loadLeaderboard() async {
        guard let id = track.id else { return }
        results = (try? await FirebaseService.shared.getTrackLeaderboard(trackId: id)) ?? []
    }
}


